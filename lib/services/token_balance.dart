import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'forditva_token_client.dart';

/// Alex's Token Server 3.0 (live 2026-10-27). Contract: API.md v3, §3-7.
const String tokenServerUrl = 'https://forditva-api.wir-in-ungarn.hu';

/// Whether this install has a wallet on the Token Server.
enum WalletState {
  /// No wallet yet: the user picks "start new" or "recovery code" first.
  none,

  /// Wallet works; the balance is the last known server state minus local use.
  ready,

  /// The server refused this install's credential (401 after a recovery on
  /// another phone) or this device already has a wallet (409 on register,
  /// e.g. after an Android reinstall). Only the recovery code helps.
  needsRecovery,
}

/// What went wrong in a wallet call, so the UI can pick the right message.
enum WalletError {
  /// Gift code or recovery code does not exist or was used by another wallet.
  invalidCode,

  /// 5 wrong gift codes in a row: no redeem for one hour.
  codeLocked,

  /// The reverse proxy's per-IP limit (HTML 429): wait at least 60 s.
  rateLimited,

  /// See [WalletState.needsRecovery].
  needsRecovery,

  /// 3 recoveries of this wallet in the last 30 days.
  recoveryLimit,

  /// This device already belongs to a different wallet.
  deviceLinked,

  /// No connection or timeout.
  network,

  /// Server error (5xx) or an answer the app does not understand.
  unavailable,
}

class WalletException implements Exception {
  final WalletError kind;
  WalletException(this.kind);

  @override
  String toString() => 'WalletException($kind)';
}

/// The user's credit in WIUs (wir-in-ungarn units) at a fixed $0.0025/WIU
/// consumer rate (10,000 WIU = $25). Every Gemini and TTS call spends WIUs
/// equal to its REAL Google cost converted to that rate (see
/// [geminiWiuCost] and gemini_tts_service.dart) — Markus, 2026-07-11: "I want
/// to earn nothing... if we reduce 1000 WIU, the user needs to be getting
/// $2.50 of real AI work for it."
///
/// Since 1.0.4 the wallet lives on the Token Server: it grants 200 WIU once
/// per wallet and adds gift codes; the app counts its own use and reports
/// the lifetime total at start/resume every 8 hours and with each redeem.
/// The old local balance and the WordPress prepaid codes are not carried
/// over (API.md §7, decision 2026-10-28: testers start fresh).
class TokenBalance {
  TokenBalance._(this._client, this._storage);

  static final TokenBalance instance = TokenBalance._(
    ForditvaTokenClient(baseUrl: tokenServerUrl),
    const FlutterSecureStorage(),
  );

  @visibleForTesting
  factory TokenBalance.forTest(
    ForditvaTokenClient client,
    FlutterSecureStorage storage,
  ) => TokenBalance._(client, storage);

  final ForditvaTokenClient _client;
  final FlutterSecureStorage _storage;

  // The server takes whole WIUs only. The fraction below 1 WIU waits here and
  // counts at a later spend (API.md §5: report the total rounded down).
  // Stored as remainder*1000 since SharedPreferences has no double.
  static const _remainderKey = 'wallet_spend_remainder_x1000';

  /// Below this, the UI nudges the user to top up soon without blocking yet
  /// (Markus, 2026-07-10: warn under 200 WIUs; 2026-10-09: lowered to 50).
  static const lowBalanceThreshold = 50;

  /// Current balance in WIUs. Listen to rebuild the status bar on change.
  /// Can go below 0 (the server accepts any reported total).
  final ValueNotifier<int> value = ValueNotifier<int>(0);

  /// Listen to react when a wallet is created, recovered or refused.
  final ValueNotifier<WalletState> state = ValueNotifier<WalletState>(
    WalletState.none,
  );

  /// True once the balance has run out — callers must block new AI requests
  /// and tell the user to top up (Markus, 2026-07-10).
  bool get isEmpty => value.value <= 0;

  /// True while there's still balance left but it's running low.
  bool get isLow => value.value > 0 && value.value < lowBalanceThreshold;

  double _fractionalRemainder = 0.0;

  /// Reads the local wallet. No network call.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fractionalRemainder = (prefs.getInt(_remainderKey) ?? 0) / 1000.0;
    if (await _client.hasLocalWallet()) {
      _apply(await _client.getLocalWallet());
      if (state.value == WalletState.none) state.value = WalletState.ready;
    }
  }

  /// At app start: syncs an existing wallet if the last sync is 8 h old.
  /// Never registers; a new install waits for the user's choice
  /// ([createWallet] or [recover]). Never throws.
  Future<void> start() async {
    try {
      if (!await _client.hasLocalWallet()) return;
      final start = await _client.initialize();
      _apply(start.wallet);
    } catch (e) {
      _handleBackground(e);
    }
  }

  /// On resume: same 8-hour rule as [start]. Never throws.
  Future<void> syncIfDue() async {
    try {
      if (!await _client.hasLocalWallet()) return;
      _apply(await _client.syncIfDue());
    } catch (e) {
      _handleBackground(e);
    }
  }

  /// Registers a new wallet (200 WIU) and returns its recovery code, to show
  /// the user once. Null if this install already had a wallet.
  Future<String?> createWallet() async {
    final hadWallet = await _client.hasLocalWallet();
    try {
      final start = await _client.initialize();
      _apply(start.wallet);
      return hadWallet ? null : start.recoveryCode;
    } catch (e) {
      // Register can succeed and the follow-up rotate fail (lost response,
      // then offline): the wallet works, the code comes from Settings.
      if (!hadWallet && await _client.hasLocalWallet()) {
        _apply(await _client.getLocalWallet());
        return null;
      }
      throw _mapError(e);
    }
  }

  /// Moves the wallet of [code] to this install.
  Future<void> recover(String code) async {
    try {
      _apply((await _client.recover(code)).wallet);
    } on ForditvaTokenException catch (e) {
      if (e.message != 'RECOVERY_REQUEST_ID_ALREADY_USED' &&
          e.message != 'RECOVERY_SESSION_SUPERSEDED') {
        throw _mapError(e);
      }
      // The client keeps the pending request for retries after a timeout;
      // here the server wants a new one (API.md §3.4), so drop it and retry.
      await _clearPendingRecovery();
      try {
        _apply((await _client.recover(code)).wallet);
      } catch (e2) {
        throw _mapError(e2);
      }
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// Redeems a gift code with the current lifetime total. Returns the added
  /// WIUs; 0 if this wallet had already redeemed the same code.
  Future<int> redeem(String code) async {
    try {
      final result = await _client.redeemGiftCode(code);
      _apply(result.wallet);
      return result.alreadyRedeemed ? 0 : result.addedTokens;
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// A new recovery code; the old one stops working.
  Future<String> rotateRecoveryCode() async {
    try {
      return await _client.rotateRecoveryCode();
    } catch (e) {
      throw _mapError(e);
    }
  }

  /// True when [input] has the gift-code shape (8 of A-H J-N P-Z 2-9, after
  /// removing spaces and dashes), checked before any network call.
  static bool isGiftCodeFormat(String input) =>
      RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(normalizeCode(input));

  /// Same for a recovery code (25 characters).
  static bool isRecoveryCodeFormat(String input) =>
      RegExp(r'^[A-HJ-NP-Z2-9]{25}$').hasMatch(normalizeCode(input));

  static String normalizeCode(String input) =>
      input.trim().replaceAll('-', '').replaceAll(' ', '').toUpperCase();

  /// Spends a real-cost-weighted fractional WIU amount (every Gemini call
  /// and every TTS play). Accumulates the fraction until a whole WIU is
  /// owed, then records it on the wallet, so small per-call costs aren't
  /// silently rounded away.
  Future<void> spendFractional(double wiuCost) async {
    if (wiuCost <= 0) return;
    _fractionalRemainder += wiuCost;
    final whole = _fractionalRemainder.floor();
    if (whole > 0) {
      _fractionalRemainder -= whole;
      value.value -= whole;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_remainderKey, (_fractionalRemainder * 1000).round());
    if (whole > 0 && await _client.hasLocalWallet()) {
      _apply(await _client.recordConsumption(whole));
    }
  }

  void _apply(ForditvaWallet wallet) {
    value.value = wallet.balance;
    state.value = WalletState.ready;
  }

  // Start/resume sync: keep the local balance on any failure; only a refused
  // credential changes the state.
  void _handleBackground(Object e) {
    final mapped = _mapError(e);
    if (mapped.kind != WalletError.needsRecovery) {
      debugPrint('Wallet sync skipped: ${mapped.kind}');
    }
  }

  // Logs only the status and detail code, never ids, codes or bodies
  // (API.md §4).
  WalletException _mapError(Object e) {
    if (e is WalletException) return e;
    if (e is FormatException) return WalletException(WalletError.invalidCode);
    if (e is http.ClientException ||
        e is SocketException ||
        e is TimeoutException) {
      return WalletException(WalletError.network);
    }
    if (e is StateError) {
      state.value = WalletState.none;
      return WalletException(WalletError.unavailable);
    }
    if (e is! ForditvaTokenException) {
      debugPrint('Wallet error: ${e.runtimeType}');
      return WalletException(WalletError.unavailable);
    }
    debugPrint('Wallet: HTTP ${e.status} ${e.message}');
    switch (e.message) {
      case 'INVALID_OR_USED_CODE':
      case 'INVALID_RECOVERY_CODE':
        return WalletException(WalletError.invalidCode);
      case 'CODE_ATTEMPTS_LOCKED':
        return WalletException(WalletError.codeLocked);
      case 'RECOVERY_LIMIT_3_PER_30_DAYS':
        return WalletException(WalletError.recoveryLimit);
      case 'DEVICE_LINKED_TO_OTHER_WALLET':
        return WalletException(WalletError.deviceLinked);
      case 'INVALID_WALLET_CREDENTIALS':
      case 'DEVICE_ALREADY_USED_ENTER_RECOVERY_CODE':
        state.value = WalletState.needsRecovery;
        return WalletException(WalletError.needsRecovery);
    }
    if (e.status == 429) return WalletException(WalletError.rateLimited);
    if (e.status == 422) return WalletException(WalletError.invalidCode);
    return WalletException(WalletError.unavailable);
  }

  Future<void> _clearPendingRecovery() async {
    await _storage.delete(key: 'forditva_v3_pending_recover_credential');
    await _storage.delete(key: 'forditva_v3_pending_recover_request');
  }
}
