// Forditva 3.0: ONLY wallet registration, occasional sync, gift vouchers,
// and anonymous recovery. Never sends text, prompts, provider names or API keys.
//
// Requires: android_id, device_info_plus, flutter_secure_storage, http.
// Integrate recordConsumption() at the EXISTING cost deduction point in the app.
// The app continues to call all AI providers DIRECTLY, as before.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ForditvaTokenException implements Exception {
  const ForditvaTokenException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'Forditva token server: $status $message';
}

class ForditvaWallet {
  const ForditvaWallet({required this.balance, required this.grantedTotal,
      required this.spentTotal, required this.revision});
  final int balance;
  final int grantedTotal;
  final int spentTotal;
  final int revision;
}

class ForditvaStart {
  const ForditvaStart({required this.wallet, required this.isNew,
      this.recoveryCode});
  final ForditvaWallet wallet;
  final bool isNew;
  final String? recoveryCode; // show once; user saves outside the app
}

class ForditvaRedeemResult {
  const ForditvaRedeemResult(this.wallet, this.addedTokens, this.alreadyRedeemed);
  final ForditvaWallet wallet;
  final int addedTokens;
  final bool alreadyRedeemed;
}

class ForditvaTokenClient {
  ForditvaTokenClient({required this.baseUrl, http.Client? httpClient,
      FlutterSecureStorage? secureStorage})
      : _http = httpClient ?? http.Client(),
        _storage = secureStorage ?? const FlutterSecureStorage() {
    if (!baseUrl.startsWith('https://')) {
      throw ArgumentError('Forditva token server requires HTTPS');
    }
  }

  final String baseUrl;
  final http.Client _http;
  final FlutterSecureStorage _storage;
  static const Duration syncInterval = Duration(hours: 8);
  static const String _prefix = 'forditva_v3_';
  Future<void> _queue = Future<void>.value();

  // Serialize local debits and network balance changes to avoid write races.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  String _randomHex(int numBytes) {
    final generator = Random.secure();
    return List<int>.generate(numBytes, (_) => generator.nextInt(256))
        .map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  }

  String _newCredential() {
    final generator = Random.secure();
    final bytes = List<int>.generate(32, (_) => generator.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<String?> _get(String name) => _storage.read(key: '$_prefix$name');
  Future<void> _put(String name, String value) =>
      _storage.write(key: '$_prefix$name', value: value);

  Future<int> _int(String key, [int defaultValue = 0]) async =>
      int.tryParse(await _get(key) ?? '') ?? defaultValue;

  Future<bool> hasLocalWallet() async => (await _get('wallet_id')) != null;

  // Android's ANDROID_ID is generally stable across reinstalls for the
  // same signing key/device/user. Apple's IDFV is NOT guaranteed stable after
  // uninstalling every app from the same vendor. Neither proves device identity.
  Future<String> _deviceId() async {
    if (Platform.isAndroid) {
      final id = await const AndroidId().getId();
      if (id != null && RegExp(r'^[a-fA-F0-9]{16}$').hasMatch(id)) {
        return 'android:${id.toLowerCase()}';
      }
    } else if (Platform.isIOS) {
      final id = (await DeviceInfoPlugin().iosInfo).identifierForVendor;
      if (id != null && RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$'
        ).hasMatch(id)) {
        return 'ios:${id.toLowerCase()}';
      }
    } else {
      throw UnsupportedError('Only Android and iOS are supported');
    }
    // This secure-storage fallback is only an INSTALLATION identifier, so it
    // can be lost on uninstall and CANNOT stop repeated welcome grants.
    var fallback = await _get('fallback_install_id');
    if (fallback == null) {
      fallback = _randomHex(16);
      await _put('fallback_install_id', fallback);
    }
    return 'install:$fallback';
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final response = await _http.post(Uri.parse('$baseUrl$path'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body)).timeout(const Duration(seconds: 20));
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // Reverse proxies may return HTML/plain text on errors (e.g. 429).
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ForditvaTokenException(response.statusCode, 'HTTP_ERROR');
      }
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ForditvaTokenException(response.statusCode, 'HTTP_ERROR');
      }
      throw const FormatException('Invalid server response');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ForditvaTokenException(response.statusCode,
          decoded['detail']?.toString() ?? 'UNKNOWN_ERROR');
    }
    return decoded;
  }

  Future<Map<String, Object?>> _auth() async {
    final walletId = await _get('wallet_id');
    final credential = await _get('credential');
    if (walletId == null || credential == null) {
      throw StateError('Wallet not initialized. Register or recover first.');
    }
    return {'wallet_id': walletId, 'credential': credential};
  }

  Future<ForditvaWallet> _wallet() async {
    final granted = await _int('granted_total');
    final spent = await _int('spent_total');
    final revision = await _int('revision');
    return ForditvaWallet(balance: granted - spent, grantedTotal: granted,
        spentTotal: spent, revision: revision);
  }

  // The local cumulative spending counter may be ahead of the server. Never
  // reduce it on a routine sync (reinstall recovery is the only exception).
  Future<ForditvaWallet> _accept(Map<String, dynamic> server,
      {bool isRecovery = false}) async {
    final serverSpent = server['spent_total'] as int;
    final spent = isRecovery ? serverSpent
        : max(await _int('spent_total'), serverSpent);
    final granted = server['granted_total'] as int;
    await _put('granted_total', granted.toString());
    await _put('spent_total', spent.toString());
    await _put('revision', (server['revision'] as int).toString());
    await _put('last_sync_ms', DateTime.now().millisecondsSinceEpoch.toString());
    return ForditvaWallet(balance: granted - spent, grantedTotal: granted,
        spentTotal: spent, revision: server['revision'] as int);
  }

  /// Present Recover as a choice BEFORE registering a first-time installation.
  /// Existing installations do not make an API call unless eight hours passed.
  Future<ForditvaStart> initialize() => _serial(() async {
    if (await hasLocalWallet()) {
      if (await _syncDue()) {
        try {
          await _sync();
        } on ForditvaTokenException catch (error) {
          // WHY: HTTP_ERROR = no JSON detail (the proxy: 502/503/504/429, or a
          // plain 500). Keep the local balance (docs/API.md §6). A server answer
          // with a detail code (for example 401 INVALID_WALLET_CREDENTIALS) is
          // surfaced: missing/revoked credentials must reach the app.
          if (error.message != 'HTTP_ERROR' && error.status < 500) rethrow;
        } on http.ClientException {
          // NOTE: package:http (1.6.0) wraps connection failures of IOClient in
          // ClientException; cronet_http and cupertino_http throw it too. The
          // app itself requires internet for AI. No wallet reset here.
        } on SocketException {
          // The same as above.
        } on HandshakeException {
          // TLS failure, for example a captive portal. Not a server answer.
        } on TimeoutException {
          // Keep last known local balance until next opportunity.
        }
      }
      return ForditvaStart(wallet: await _wallet(), isNew: false);
    }
    var credential = await _get('credential');
    credential ??= _newCredential();
    // Persist before request; retries do NOT claim another welcome grant.
    await _put('credential', credential);
    final result = await _post('/v3/register', {
      'device_id': await _deviceId(), 'credential': credential,
    });
    await _put('wallet_id', result['wallet_id'] as String);
    final wallet = await _accept(result);
    var recoveryCode = result['recovery_code'] as String?;
    if (recoveryCode == null) {
      // First registration may have succeeded on the server while its HTTP
      // response was lost. The retry proves ownership via the same credential
      // but the original one-time recovery code can no longer be returned.
      // Generate a fresh code for the user instead.
      final rotated = await _post('/v3/recovery/rotate', await _auth());
      recoveryCode = rotated['recovery_code'] as String?;
    }
    return ForditvaStart(wallet: wallet,
        isNew: result['first_registration'] as bool,
        recoveryCode: recoveryCode);
  });

  Future<bool> _syncDue() async {
    final last = await _int('last_sync_ms');
    if (last <= 0) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= syncInterval.inMilliseconds; // clock going backward: defer
  }

  Future<ForditvaWallet> _sync() async {
    final result = await _post('/v3/sync', {
      ...await _auth(), 'spent_total': await _int('spent_total')});
    return _accept(result);
  }

  /// At startup, resume or before a normal app action; never polls faster
  /// than once every 8 hours. No timer, push, background job or AI call.
  Future<ForditvaWallet> syncIfDue() => _serial(() async {
    if (await _syncDue()) return _sync();
    return _wallet();
  });

  Future<ForditvaWallet> getLocalWallet() => _serial(_wallet);

  /// Call ONCE for each cost already calculated by the EXISTING Dart logic.
  /// Do not call from the server, and do not call again for the same usage.
  /// If needed, the existing app must ensure its charge event is idempotent.
  /// Whole WIU only: the app keeps the exact fraction itself and reports its
  /// lifetime total rounded down (docs/API.md §5).
  Future<ForditvaWallet> recordConsumption(int tokens) => _serial(() async {
    if (tokens < 0) throw ArgumentError.value(tokens, 'tokens');
    if (!await hasLocalWallet()) throw StateError('Wallet not initialized');
    final spent = await _int('spent_total');
    await _put('spent_total', (spent + tokens).toString());
    return _wallet();
  });

  Future<ForditvaRedeemResult> redeemGiftCode(String input) => _serial(() async {
    final code = input.trim().replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      throw const FormatException('Gift code requires eight valid characters');
    }
    final result = await _post('/v3/redeem', {
      ...await _auth(), 'spent_total': await _int('spent_total'), 'code': code,
    });
    return ForditvaRedeemResult(await _accept(result),
        result['amount'] as int, result['already_redeemed'] as bool);
  });

  // WHY: with these two answers the stored request_id can never succeed again
  // (server/app.py recover). Every other answer keeps the pending request.
  static const Set<String> _deadRecoveryRequest = {
    'RECOVERY_REQUEST_ID_ALREADY_USED', 'RECOVERY_SESSION_SUPERSEDED',
  };

  Future<void> _deletePendingRecovery() async {
    await _storage.delete(key: '${_prefix}pending_recover_credential');
    await _storage.delete(key: '${_prefix}pending_recover_request');
  }

  /// Restore from the most recently synchronized server state. All unsynced
  /// spending since then is irrecoverable if the app was uninstalled.
  /// At most three successful NEW recoveries per rolling 30 days.
  Future<ForditvaStart> recover(String input) => _serial(() async {
    final code = input.trim().replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{25}$').hasMatch(code)) {
      throw const FormatException('Recovery code requires 25 valid characters');
    }
    ForditvaWallet wallet;
    try {
      wallet = await _recoverOnce(code);
    } on ForditvaTokenException catch (error) {
      if (!_deadRecoveryRequest.contains(error.message)) rethrow;
      // NOTE: one retry with a new request_id. A second error goes to the caller.
      wallet = await _recoverOnce(code);
    }
    return ForditvaStart(wallet: wallet, isNew: false);
  });

  Future<ForditvaWallet> _recoverOnce(String code) async {
    // Persist pending request ID and secret, so retry after connection timeout
    // reuses the same operation (does not use another recovery allowance).
    var pendingSecret = await _get('pending_recover_credential');
    var pendingRequest = await _get('pending_recover_request');
    pendingSecret ??= _newCredential();
    pendingRequest ??= _randomHex(16);
    await _put('pending_recover_credential', pendingSecret);
    await _put('pending_recover_request', pendingRequest);
    // NOTE: a timeout or a network error is not caught here, so the pending
    // request stays for the next try.
    final Map<String, dynamic> data;
    try {
      data = await _post('/v3/recover', {
        'recovery_code': code,
        'device_id': await _deviceId(),
        'new_credential': pendingSecret,
        'request_id': pendingRequest,
      });
    } on ForditvaTokenException catch (error) {
      if (_deadRecoveryRequest.contains(error.message)) {
        await _deletePendingRecovery();
      }
      rethrow; // every other server answer keeps the pending request
    }
    await _put('wallet_id', data['wallet_id'] as String);
    await _put('credential', pendingSecret);
    final wallet = await _accept(data, isRecovery: true);
    await _deletePendingRecovery();
    return wallet;
  }

  /// Replace lost/compromised recovery code while current installation works.
  /// Does not consume one of the three reactivations.
  Future<String> rotateRecoveryCode() => _serial(() async {
    final data = await _post('/v3/recovery/rotate', await _auth());
    return data['recovery_code'] as String;
  });

  void dispose() => _http.close();
}
