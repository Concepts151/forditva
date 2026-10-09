import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../services/gemini_cost.dart';
import '../services/token_balance.dart';
import 'tutor_prompts.dart';

/// The three Tutor tabs (Markus, 2026-10-09), in display order.
enum TutorMode {
  /// "Verstehen / Megértés / Understanding": Method 1, level-dependent.
  understanding,

  /// "Dekodieren / Dekódolás / Decoding": the Decoder.
  decoding,

  /// "Lernfokus / Tanulási fókusz / Learning Focus": Mode 3.
  focus,
}

/// One sentence offered in the sentence picker: the Hungarian sentence and
/// its translation into the explanation language.
class TutorSentence {
  final String hu;
  final String translation;
  const TutorSentence(this.hu, this.translation);
}

/// Gemini calls behind the Tutor page. Every call is billed in WIU like any
/// other Gemini request (same [geminiWiuCost], including the fee margin).
class TutorService {
  static const _model = 'gemini-flash-latest';

  /// Lets the Tutor page abandon an in-flight request (when "Answer now"
  /// delivered first, or the page closed). One client per request.
  final http.Client _client = http.Client();

  void cancel() => _client.close();

  /// Languages the handoff prompts support as explanation language.
  static const supportedLanguages = ['DE', 'EN', 'NL', 'FR', 'IT', 'RU', 'ES'];

  static const _englishNames = {
    'DE': 'German',
    'EN': 'English',
    'NL': 'Dutch',
    'FR': 'French',
    'IT': 'Italian',
    'RU': 'Russian',
    'ES': 'Spanish',
  };

  // Mode 3's prompt is written in German, so it gets German language names
  // ("Bei {{TARGET_LANGUAGE}} = Deutsch").
  static const _germanNames = {
    'DE': 'Deutsch',
    'EN': 'Englisch',
    'NL': 'Niederländisch',
    'FR': 'Französisch',
    'IT': 'Italienisch',
    'RU': 'Russisch',
    'ES': 'Spanisch',
  };

  // The handoffs send the Hungarian text as the user message; the prompts'
  // own {{HU_TEXT}} slot then points there instead of repeating it.
  static const _textInUserMessage = '(the Hungarian text is the user message)';

  static const _retryInstruction =
      'Return the result again as valid JSON matching the required structure. '
      'Do not add any other text.';

  /// Splits [text] into sentences and translates each into [langCode], for
  /// the sentence picker. One cheap text request.
  Future<List<TutorSentence>> splitSentences(
    String text,
    String langCode,
  ) async {
    final language = _englishNames[langCode] ?? 'German';
    final system = '''
Split the Hungarian text in the user message into its sentences and translate each sentence into $language.

Rules:
- Keep every Hungarian sentence exactly as written: same words, spelling, accents and punctuation. Do not correct or shorten anything.
- Keep the original order. Together the sentences must cover the whole text.
- Direct speech together with its introducing clause remains one sentence.
- "tr" is a natural translation of that one sentence into $language.

Return only a JSON array: [{"hu": "...", "tr": "..."}]''';
    final list = await _requestJson(system, text, (v) {
      return v.every((e) => e['hu'] is String);
    });
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
    final code = supportedLanguages.contains(langCode) ? langCode : 'DE';
    switch (mode) {
      case TutorMode.understanding:
        final system = method1Prompt
            .replaceAll('{{TARGET_LANGUAGE}}', _englishNames[code]!)
            .replaceAll('{{LEVEL}}', level.toString().padLeft(2, '0'))
            .replaceAll('{{HU_TEXT}}', _textInUserMessage);
        final list = await _requestJson(system, huText, _validMethod1, fast: fast);
        // The handoff allows 1 to 3 items; trim any extra rather than fail.
        for (final s in list) {
          final items = s['items'] as List;
          if (items.length > 3) s['items'] = items.sublist(0, 3);
        }
        return list;
      case TutorMode.decoding:
        final system = '$decoderBasePrompt\n\n${decoderProfiles[code]!}';
        return _requestJson(system, huText, _validDecoder, fast: fast);
      case TutorMode.focus:
        final system = mode3Prompt
            .replaceAll('{{TARGET_LANGUAGE}}', _germanNames[code]!)
            .replaceAll('{{HU_TEXT}}', _textInUserMessage);
        return _requestJson(system, huText, _validMode3, fast: fast);
    }
  }

  static bool _validItems(dynamic items, {int? max}) {
    if (items is! List || items.isEmpty) return false;
    if (max != null && items.length > max * 2) return false;
    return items.every(
      (i) =>
          i is Map &&
          i['term'] is String &&
          i['explanation'] is String &&
          i['example_hu'] is String &&
          i['example_translation'] is String,
    );
  }

  static bool _validMethod1(List v) => v.every(
    (s) =>
        s is Map &&
        s['hu'] is String &&
        s['intro'] is String &&
        _validItems(s['items'], max: 3),
  );

  static bool _validDecoder(List v) => v.every(
    (s) =>
        s is Map &&
        s['hu'] is String &&
        s['direct'] is String &&
        s['correct'] is String,
  );

  static bool _validMode3(List v) => v.every(
    (s) => s is Map && s['hu'] is String && _validItems(s['items']),
  );

  /// Parses a model reply into a JSON array, tolerating a ```json fence.
  @visibleForTesting
  static List<Map<String, dynamic>>? parseArray(String reply) {
    var text = reply.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List || decoded.isEmpty) return null;
      if (decoded.any((e) => e is! Map)) return null;
      return [for (final e in decoded) Map<String, dynamic>.from(e as Map)];
    } catch (_) {
      return null;
    }
  }

  /// Sends [system] + [user], parses a JSON array and checks it with
  /// [isValid]; retries once with the handoffs' retry instruction.
  Future<List<Map<String, dynamic>>> _requestJson(
    String system,
    String user,
    bool Function(List<Map<String, dynamic>>) isValid, {
    bool fast = true,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final reply = await _call(
        system,
        attempt == 0 ? user : '$user\n\n$_retryInstruction',
        fast: fast,
      );
      final parsed = parseArray(reply);
      if (parsed != null && isValid(parsed)) return parsed;
      debugPrint('Tutor: invalid JSON on attempt ${attempt + 1}');
    }
    throw const FormatException('Tutor reply was not valid JSON');
  }

  Future<String> _call(String system, String user, {bool fast = true}) async {
    final key = dotenv.env['GEMINI_API_KEY']!;
    final response = await _client.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_model:generateContent?key=$key',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': user},
            ],
          },
        ],
        // Low creativity, as every handoff asks; JSON-only output.
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
          'maxOutputTokens': 32768,
          if (fast) 'thinkingConfig': {'thinkingBudget': 0},
        },
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    final usage = data['usageMetadata'] as Map<String, dynamic>?;
    TokenBalance.instance.spendFractional(
      geminiWiuCost(
        promptTokens: usage?['promptTokenCount'] as int? ?? 0,
        outputTokens: billableOutputTokens(
          prompt: usage?['promptTokenCount'] as int? ?? 0,
          candidates: usage?['candidatesTokenCount'] as int? ?? 0,
          thoughts: usage?['thoughtsTokenCount'] as int?,
        ),
      ),
    );
    final parts = data['candidates']?[0]?['content']?['parts'] as List?;
    return (parts == null || parts.isEmpty)
        ? ''
        : (parts[0]['text'] as String? ?? '');
  }
}
