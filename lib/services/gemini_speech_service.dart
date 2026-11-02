import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/language_enum.dart';
import 'ai/ai_models.dart';
import 'ai/gemini_firebase.dart';
import 'ai/text_ai.dart';

/// Voice input: the app records WAV audio itself and Gemini transcribes it
/// through Firebase AI Logic (no key in the app).
///
/// Replaced, 2026-10-20: the phone's built-in recognizer (Android plays its
/// start sound on every restart after a pause, returns no punctuation, and
/// some phones have no Hungarian at all) and Google Cloud STT (no Hungarian
/// punctuation, 60 s limit, needed an API key in the app). Measured
/// 2026-10-12: correct Hungarian punctuation, 2 to 3.5 s, about 1/18 of the
/// Cloud STT price.
///
/// Not billed in WIU, like Cloud STT before it (Markus decides).
class GeminiSpeechService {
  /// Longest recording either mic accepts. Gemini takes far longer audio;
  /// this keeps the inline request (16 kHz mono WAV, 32 KB/s, base64)
  /// well under Firebase's 20 MB limit.
  static const maxDuration = Duration(minutes: 5);

  /// Mic level (0..1, from dBFS -45..0) that counts as speech. Audio that
  /// never reached it is not sent: on near-silence Gemini invents a
  /// plausible sentence (seen in the 2026-10-12 test) instead of returning
  /// nothing.
  static const double voiceLevel = 0.35;

  /// Normalizes a recorder amplitude (dBFS) to the 0..1 scale of
  /// [voiceLevel].
  static double level(double dbfs) => ((dbfs + 45) / 45).clamp(0.0, 1.0);

  static String _prompt(Language lang) {
    final name = lang.fullName;
    return 'Transcribe this audio recording. The speaker is speaking $name.\n'
        '- Write exactly the words spoken, in $name. Do not translate, '
        'summarize, correct or answer anything.\n'
        '- Add correct punctuation and capitalization.\n'
        '- When the speaker dictates a punctuation mark by name (for example '
        '"Punkt", "Komma", "pont", "vessző", "full stop", "comma", '
        '"question mark"), write the mark instead of the word.\n'
        '- If a few words are in another language, write them as spoken.\n'
        '- If there is no clear speech, return nothing.\n'
        'Return only the transcript.';
  }

  /// Transcribes [audio] (16 kHz mono WAV) spoken in [lang]. Returns '' when
  /// nothing was understood; throws when the request itself failed.
  Future<String> transcribe(File audio, Language lang) async {
    final watch = Stopwatch()..start();
    final reply = await geminiGenerate(
      AiModels.geminiFlashLite,
      TextAiRequest(user: _prompt(lang), temperature: 0),
      file: GeminiFile('audio/wav', await audio.readAsBytes()),
    );
    debugPrint(
      'Voice input: ${watch.elapsedMilliseconds} ms, '
      '${reply.result.inputTokens} in / ${reply.result.outputTokens} out',
    );
    return reply.result.text.trim();
  }
}
