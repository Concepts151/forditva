import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/ai/ai_router.dart';
import 'tutor_core.dart';

export 'tutor_core.dart'
    show TutorMode, TutorNoHungarianException, TutorSentence;

/// AI calls behind the Tutor page. The model is chosen in [aiRoutes]
/// ([AiTask.tutor], [AiTask.tutorSentences]); every call is billed in WIU at
/// that model's price, including the fee margin. Prompts, JSON checks and
/// parsing live in tutor_core.dart.
class TutorService {
  /// Lets the Tutor page abandon an in-flight request (when "Answer now"
  /// delivered first, or the page closed). One client per request.
  final http.Client _client = http.Client();

  void cancel() => _client.close();

  /// Languages the handoff prompts support as explanation language.
  static const supportedLanguages = tutorLanguages;

  /// Splits [text] into sentences and translates each into [langCode], for
  /// the sentence picker. One cheap text request.
  Future<List<TutorSentence>> splitSentences(
    String text,
    String langCode,
  ) async {
    final list = await _requestJson(
      sentenceSplitPrompt(langCode),
      text,
      validSentences,
      task: AiTask.tutorSentences,
    );
    return [
      for (final e in list)
        TutorSentence(
          (e['hu'] as String).trim(),
          ((e['tr'] as String?) ?? '').trim(),
        ),
    ].where((s) => s.hu.isNotEmpty).toList();
  }

  /// Runs [mode] on [huText], explained in [langCode]. [level] (1-99) only
  /// matters for [TutorMode.understanding]. Returns the parsed JSON array.
  /// [fast] turns the model's thinking off: about 4 s instead of 15 s to
  /// 2 minutes, with occasional small grammar slips. Markus, 2026-10-09:
  /// accurate (thinking) by default, with an "Answer now" button that asks
  /// for the fast version so nobody has to wait.
  Future<List<Map<String, dynamic>>> explain({
    required TutorMode mode,
    required String huText,
    required String langCode,
    required int level,
    bool fast = false,
  }) async {
    final list = await _requestJson(
      tutorSystemPrompt(mode, langCode, level),
      huText,
      tutorValidator(mode),
      fast: fast,
    );
    if (mode == TutorMode.understanding) {
      // The handoff allows 1 to 3 items; trim any extra rather than fail.
      for (final s in list) {
        final items = s['items'] as List;
        if (items.length > 3) s['items'] = items.sublist(0, 3);
      }
    }
    return list;
  }

  /// Parses a model reply into a JSON array, tolerating a ```json fence.
  @visibleForTesting
  static List<Map<String, dynamic>>? parseArray(String reply) =>
      parseTutorArray(reply);

  /// Sends [system] + [user], parses a JSON array and checks it with
  /// [isValid]; retries once with the handoffs' retry instruction.
  Future<List<Map<String, dynamic>>> _requestJson(
    String system,
    String user,
    bool Function(List<Map<String, dynamic>>) isValid, {
    bool fast = true,
    AiTask task = AiTask.tutor,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final result = await runAiTask(
        task,
        TextAiRequest(
          system: system,
          user: attempt == 0 ? user : '$user\n\n$tutorRetryInstruction',
          json: true,
          // Low creativity, as every handoff asks; JSON-only output.
          temperature: 0.2,
          thinking: !fast,
          maxOutputTokens: 32768,
        ),
        client: _client,
      );
      if (isEmptyTutorReply(result.text)) {
        throw const TutorNoHungarianException();
      }
      final parsed = parseTutorArray(result.text);
      if (parsed != null && isValid(parsed)) return parsed;
      debugPrint('Tutor: invalid JSON on attempt ${attempt + 1}');
    }
    throw const FormatException('Tutor reply was not valid JSON');
  }
}
