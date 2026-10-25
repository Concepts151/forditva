import 'dart:convert';

import 'tutor_prompts.dart';

// Pure Dart (no Flutter): the Tutor's prompts, JSON checks and parsing,
// shared by TutorService and the model comparison tool in tool/.

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

/// Languages the handoff prompts support as explanation language.
const tutorLanguages = ['DE', 'EN', 'NL', 'FR', 'IT', 'RU', 'ES'];

const _englishNames = {
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
const _germanNames = {
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
const _textInUserMessage = '(the Hungarian text is the user message)';

const tutorRetryInstruction =
    'Return the result again as valid JSON matching the required structure. '
    'Do not add any other text.';

/// System prompt for the sentence picker: split [langCode]'s text into
/// sentences with a translation each.
String sentenceSplitPrompt(String langCode) {
  final language = _englishNames[langCode] ?? 'German';
  return '''
Split the Hungarian text in the user message into its sentences and translate each sentence into $language.

Rules:
- Keep every Hungarian sentence exactly as written: same words, spelling, accents and punctuation. Do not correct or shorten anything.
- Keep the original order. Together the sentences must cover the whole text.
- Direct speech together with its introducing clause remains one sentence.
- "tr" is a natural translation of that one sentence into $language.

Return only a JSON array: [{"hu": "...", "tr": "..."}]''';
}

bool validSentences(List<Map<String, dynamic>> v) =>
    v.every((e) => e['hu'] is String);

/// System prompt for [mode], explained in [langCode]. [level] (1-99) only
/// matters for [TutorMode.understanding].
String tutorSystemPrompt(TutorMode mode, String langCode, int level) {
  final code = tutorLanguages.contains(langCode) ? langCode : 'DE';
  switch (mode) {
    case TutorMode.understanding:
      return method1Prompt
          .replaceAll('{{TARGET_LANGUAGE}}', _englishNames[code]!)
          .replaceAll('{{LEVEL}}', level.toString().padLeft(2, '0'))
          .replaceAll('{{HU_TEXT}}', _textInUserMessage);
    case TutorMode.decoding:
      return '$decoderBasePrompt\n\n${decoderProfiles[code]!}';
    case TutorMode.focus:
      return mode3Prompt
          .replaceAll('{{TARGET_LANGUAGE}}', _germanNames[code]!)
          .replaceAll('{{HU_TEXT}}', _textInUserMessage);
  }
}

/// The structure check for [mode]'s reply.
bool Function(List<Map<String, dynamic>>) tutorValidator(TutorMode mode) =>
    switch (mode) {
      TutorMode.understanding => _validMethod1,
      TutorMode.decoding => _validDecoder,
      TutorMode.focus => _validMode3,
    };

bool _validItems(dynamic items, {int? max}) {
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

bool _validMethod1(List v) => v.every(
  (s) =>
      s is Map &&
      s['hu'] is String &&
      s['intro'] is String &&
      _validItems(s['items'], max: 3),
);

bool _validDecoder(List v) => v.every(
  (s) =>
      s is Map &&
      s['hu'] is String &&
      s['direct'] is String &&
      s['correct'] is String,
);

bool _validMode3(List v) =>
    v.every((s) => s is Map && s['hu'] is String && _validItems(s['items']));

/// Parses a model reply into a JSON array, tolerating a ```json fence.
/// JSON modes that only allow an object at the top (DeepSeek's) answer
/// either one sentence object (has "hu") or an object wrapping the array in
/// a single field; both are accepted.
List<Map<String, dynamic>>? parseTutorArray(String reply) {
  var text = reply.trim();
  final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  try {
    var decoded = jsonDecode(text);
    if (decoded is Map && decoded.containsKey('hu')) {
      decoded = [decoded];
    } else if (decoded is Map) {
      final lists = decoded.values.whereType<List>().toList();
      if (lists.length != 1) return null;
      decoded = lists.single;
    }
    if (decoded is! List || decoded.isEmpty) return null;
    if (decoded.any((e) => e is! Map)) return null;
    return [for (final e in decoded) Map<String, dynamic>.from(e as Map)];
  } catch (_) {
    return null;
  }
}
