import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/markup_text.dart';
import '../widgets/wallet_dialogs.dart';

/// Thrown by [AiConsent.require] when the user does not agree. UI code that
/// already catches errors from the AI calls shows its normal error; callers
/// that want to stay silent can catch this type.
class AiConsentDeclined implements Exception {
  const AiConsentDeclined();
  @override
  String toString() => 'AiConsentDeclined';
}

/// The user's consent to send content to the external AI service (Markus,
/// 2026-11-04). `null` = never asked (shows the welcome page), `true` =
/// agreed, `false` = declined or withdrawn in Settings. Without consent every
/// AI call asks again through [require] and fails if the answer is no.
class AiConsent {
  static const _key = 'ai_consent_v1';
  static const privacyUrl = 'https://wir-in-ungarn.hu/datenschutz-forditva/';

  /// Lets the gate show its dialog from a service, without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final ValueNotifier<bool?> granted = ValueNotifier<bool?>(null);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    granted.value = prefs.getBool(_key);
  }

  static Future<void> set(bool value) async {
    granted.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  static Future<bool>? _asking;

  /// Returns when AI use is allowed; asks the user if it is not. Throws
  /// [AiConsentDeclined] on "no". Parallel callers share one dialog.
  static Future<void> require() async {
    if (granted.value == true) return;
    final ok = await (_asking ??= _ask().whenComplete(() => _asking = null));
    if (!ok) throw const AiConsentDeclined();
  }

  static Future<bool> _ask() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final result = await showConsentDialog(context);
    if (result == true) await set(true);
    return result == true;
  }

  /// The same text as the welcome page's "Your choice" block.
  static Future<bool?> showConsentDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Same look as the wallet dialogs: white card, green icon and title,
    // Roboto Condensed, rounded green button.
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AppDialog(
            icon: Icons.privacy_tip_outlined,
            title: loc.welcomeChoiceHeading,
            body: Text.rich(
              markupSpan('${loc.welcomeChoiceBody}\n\n${loc.welcomeMore}'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            actions: [
              primaryDialogButton(
                loc.welcomeAgree,
                () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  loc.welcomeNotNow,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF436F4D),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
