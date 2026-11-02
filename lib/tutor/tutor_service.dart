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
    return _trimItems(mode, list);
  }

  // The handoff allows 1 to 3 items; trim any extra rather than fail.
  static List<Map<String, dynamic>> _trimItems(
    TutorMode mode,
    List<Map<String, dynamic>> list,
  ) {
    if (mode == TutorMode.understanding) {
      for (final s in list) {
        final items = s['items'] as List;
        if (items.length > 3) s['items'] = items.sublist(0, 3);
      }
    }
    return list;
  }

  /// The same accurate answer as [explain] (thinking on), but yielded as it
  /// is written: every yield is the list of sentences finished so far, and
  /// the last one is the complete, checked answer. An answer the stream parser
  /// could not use is asked for again in one piece, as before.
  Stream<List<Map<String, dynamic>>> explainStream({
    required TutorMode mode,
    required String huText,
    required String langCode,
    required int level,
  }) async* {
    final parser = IncrementalJsonArray();
    final isValid = tutorValidator(mode);
    final finished = <Map<String, dynamic>>[];
    final raw = StringBuffer();
    await for (final piece in runAiTaskStream(
      AiTask.tutor,
      TextAiRequest(
        system: tutorSystemPrompt(mode, langCode, level),
        user: huText,
        json: true,
        temperature: 0.2,
        thinking: true,
        maxOutputTokens: 32768,
      ),
      client: _client,
    )) {
      raw.write(piece);
      var grew = false;
      for (final sentence in parser.add(piece)) {
        if (isValid([sentence])) {
          finished.add(sentence);
          grew = true;
        }
      }
      if (grew) yield _trimItems(mode, [for (final s in finished) Map.of(s)]);
    }
    final reply = raw.toString();
    if (isEmptyTutorReply(reply)) throw const TutorNoHungarianException();
    final parsed = parseTutorArray(reply);
    if (parsed != null && isValid(parsed)) {
      yield _trimItems(mode, parsed);
      return;
    }
    debugPrint('Tutor: streamed reply was not valid JSON, asking again');
    yield await explain(
      mode: mode,
      huText: huText,
      langCode: langCode,
      level: level,
    );
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
