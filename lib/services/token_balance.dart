import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_grant_service.dart';

/// The user's prepaid credit, measured in WIUs (wir-in-ungarn units) at a
/// fixed $0.0025/WIU consumer rate (10,000 WIU = $25). Redeeming a prepaid
/// code adds its value here. Every Gemini and TTS call spends WIUs equal to
/// its REAL Google cost converted to that rate (see [geminiWiuCost] and
/// gemini_tts_service.dart), not a flat per-token count — Markus, 2026-07-11:
/// "I want to earn nothing... if we reduce 1000 WIU, the user needs to be
/// getting $2.50 of real AI work for it." The "Current Status" bar in
/// Profile settings reads this. Persisted so the balance survives restarts.
class TokenBalance {
  TokenBalance._();
  static final TokenBalance instance = TokenBalance._();

  static const _key = 'token_balance_wiu';
  static const _welcomeKey = 'welcome_granted';
  // Stored as remainder*1000 (an int) since SharedPreferences has no double.
  static const _remainderKey = 'token_balance_remainder_x1000';

  // iOS Keychain survives app uninstall (unlike SharedPreferences), so on
  // iOS this is the real guard against a reinstall re-granting the welcome
  // bonus (Markus, 2026-07-12: confirmed reinstalls should not re-grant).
  static const _secureStorage = FlutterSecureStorage();

  // Android has no client-only equivalent to the Keychain, so it checks the
  // wir-in-ungarn.hu backend by ANDROID_ID instead (welcome-grant/check and
  // /claim, live as of 2026-07-12 per Alam).
  static const _androidId = AndroidId();
  final _welcomeGrantService = WelcomeGrantService();

  /// One-time WIUs credited to every new install on first launch (Markus,
  /// 2026-07-12: 100, not 500 — enough for 50-100 translations before the
  /// user needs to buy their next prepaid code).
  static const welcomeGrant = 100;

  /// Below this, the UI nudges the user to top up soon without blocking yet
  /// (Markus, 2026-07-10: warn under 200 WIUs; 2026-10-09: lowered to 50,
  /// since 200 was above the 100 WIU welcome grant and every new user saw
  /// the warning from the start).
  static const lowBalanceThreshold = 50;

  /// Current balance in WIUs. Listen to rebuild the status bar on change.
  final ValueNotifier<int> value = ValueNotifier<int>(0);

  /// True once the balance has run out — callers must block new AI requests
  /// and tell the user to top up (Markus, 2026-07-10).
  bool get isEmpty => value.value <= 0;

  /// True while there's still balance left but it's running low.
  bool get isLow => value.value > 0 && value.value < lowBalanceThreshold;

  // Carries fractional WIU cost between calls (every call now costs a real-
  // dollar-weighted fraction of a WIU, rarely a whole number) so small costs
  // accumulate correctly instead of rounding to 0 each time.
  double _fractionalRemainder = 0.0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value.value = prefs.getInt(_key) ?? 0;
    _fractionalRemainder = (prefs.getInt(_remainderKey) ?? 0) / 1000.0;
  }

  /// Credits the one-time welcome grant on the very first launch of this
  /// install. On iOS checked against the Keychain; on Android checked
  /// against the wir-in-ungarn.hu backend by ANDROID_ID — both survive an
  /// uninstall, so a reinstall on the same device does not re-grant. If the
  /// Android network check fails (offline, server error), grants anyway
  /// rather than blocking app startup; the claim call is best-effort too.
  /// Safe to call every launch: it grants only once.
  Future<void> grantWelcomeIfFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_welcomeKey) ?? false) return;

    if (Platform.isIOS) {
      final alreadyGranted = await _secureStorage.read(key: _welcomeKey);
      if (alreadyGranted == 'true') {
        await prefs.setBool(_welcomeKey, true);
        return;
      }
    } else if (Platform.isAndroid) {
      try {
        final deviceId = await _androidId.getId();
        if (deviceId != null &&
            await _welcomeGrantService.checkGranted(deviceId)) {
          await prefs.setBool(_welcomeKey, true);
          return;
        }
      } catch (_) {
        // Network/server issue — fall through and grant locally rather than
        // block the user on startup.
      }
    }

    value.value += welcomeGrant;
    await prefs.setBool(_welcomeKey, true);
    await prefs.setInt(_key, value.value);

    if (Platform.isIOS) {
      await _secureStorage.write(key: _welcomeKey, value: 'true');
    } else if (Platform.isAndroid) {
      try {
        final deviceId = await _androidId.getId();
        if (deviceId != null) await _welcomeGrantService.claim(deviceId);
      } catch (_) {
        // Best-effort — if this fails to record, worst case this device can
        // re-grant once more on a future reinstall.
      }
    }
  }

  /// Adds [amount] WIUs (e.g. after redeeming a code) and persists the total.
  Future<void> add(int amount) async {
    if (amount <= 0) return;
    value.value += amount;
    await _persist();
  }

  /// Spends a real-cost-weighted fractional WIU amount (every Gemini call
  /// and every TTS play). Accumulates the fraction until a whole WIU is
  /// owed, then debits the visible integer balance, so small per-call costs
  /// aren't silently rounded away.
  Future<void> spendFractional(double wiuCost) async {
    if (wiuCost <= 0) return;
    _fractionalRemainder += wiuCost;
    final whole = _fractionalRemainder.floor();
    if (whole > 0) {
      _fractionalRemainder -= whole;
      value.value = (value.value - whole).clamp(0, value.value);
    }
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.value);
    await prefs.setInt(_remainderKey, (_fractionalRemainder * 1000).round());
  }
}
