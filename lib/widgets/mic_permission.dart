import 'package:flutter/material.dart';
import 'package:forditva/flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Asks for the microphone before [recorder] starts. Android shows its
/// permission dialog the first time; without it the recorder gets no audio
/// and voice input silently does nothing (fresh Play install, 2026-10-24).
/// Returns false, with a message that links to the app's settings, when the
/// user refuses.
Future<bool> ensureMicPermission(
  BuildContext context,
  AudioRecorder recorder,
) async {
  if (await recorder.hasPermission()) return true;
  if (!context.mounted) return false;
  final loc = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(loc.microphonePermissionNeeded),
      action: SnackBarAction(label: loc.settings, onPressed: openAppSettings),
      // A SnackBar with an action stays until tapped by default, and this
      // one covers the Conversation page's microphone button.
      persist: false,
    ),
  );
  return false;
}
