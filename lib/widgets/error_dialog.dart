import 'package:flutter/material.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../services/gemini_tts_service.dart';

const Color _navGreen = Color(0xFF436F4D);

/// A friendly, large-text error popup for genuine failures (no internet, the
/// translation/AI service is unavailable). Deliberately jargon-free and big, so
/// any user, including an 80-year-old, understands it (Markus's request). The
/// defaults are localized to the app UI language; pass [title]/[message] to
/// override.
Future<void> showFriendlyError(
  BuildContext context, {
  String? title,
  String? message,
}) {
  final loc = AppLocalizations.of(context)!;
  return showDialog(
    context: context,
    builder:
        (_) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 56, color: _navGreen),
                const SizedBox(height: 16),
                Text(
                  title ?? loc.errorTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _navGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message ?? loc.errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

/// Tells the user why read-aloud failed, using the reason
/// [GeminiTtsService] reports (Alex's function: switched off, busy, or a
/// plain failure).
Future<void> showTtsError(BuildContext context, Object error) {
  final loc = AppLocalizations.of(context)!;
  final failure = error is TtsException ? error.failure : TtsFailure.failed;
  return showFriendlyError(
    context,
    message: switch (failure) {
      TtsFailure.unavailable => loc.readAloudUnavailable,
      TtsFailure.busy => loc.readAloudBusy,
      TtsFailure.failed => loc.ttsFailed,
    },
  );
}
