import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart' show FinishReason;
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import 'ai/ai_models.dart';
import 'ai/gemini_firebase.dart';
import 'ai/text_ai.dart';
import 'gemini_cost.dart';
import 'token_balance.dart';

/// Image translation / interpretation via Gemini vision.
///
/// Drop-in replacement for the old OpenAI-based ChatGptService: same
/// [processImage] signature, so the Image page is unchanged apart from the
/// service it instantiates.
class GeminiImageService {
  GeminiImageService();

  /// Through Firebase AI Logic, like every Gemini call (no key in the app).
  static const _model = AiModels.geminiFlash;

  static const Map<String, String> _langNames = {
    "EN": "English",
    "DE": "German",
    "HU": "Hungarian",
    "NL": "Dutch",
    "FR": "French",
    "ES": "Spanish",
    "RU": "Russian",
    "IT": "Italian",
  };

  static const Map<String, String> _dateFormats = {
    "EN": "MM/DD/YYYY",
    "DE": "DD.MM.YYYY",
    "HU": "YYYY.MM.DD",
    "NL": "DD-MM-YYYY",
    "FR": "DD/MM/YYYY",
    "ES": "DD/MM/YYYY",
    "RU": "DD.MM.YYYY",
    "IT": "DD/MM/YYYY",
  };

  String _buildTranslationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;
    final targetDateFormat = _dateFormats[toLang] ?? "YYYY-MM-DD";

    return '''
You are an AI assistant for image translation & document interpretation.

Attached is an image or PDF document containing $fromLangName text. The target language is $toLangName.

Your task:
- Extract only fully visible $fromLangName text segments. Skip any partially visible, cut-off, or incomplete text.
- If the document has multiple pages, process all of them in order.
- If a segment is not clearly legible, set both "o" and "t" fields to "{unsafe}".
- Translate each clearly legible segment individually into $toLangName.
- Convert any dates into $targetDateFormat.
- Do not add any explanations, summaries, or instructions.

STRICT OUTPUT FORMAT:
Return the result ONLY as valid JSON array, exactly like this:

[
  { "o": "original text here", "t": "translated text here" }
]

Do not add any comments, markdown, explanations, or text outside this JSON array. Only return valid JSON.
If you are unable to detect any text, return: []
''';
  }

  String _buildQuestionPrompt(String question, String answerLangName) {
    return '''
You are an AI assistant helping a user understand a document (image or PDF).

The user has a question about the attached document. Answer using only information found in the document.

Question: $question

Instructions:
- Answer in $answerLangName.
- Base your answer only on the document's content.
- If the document doesn't contain enough information to answer, say so clearly.
- Reply in plain text only: no markdown, no HTML, no code fences.
''';
  }

  String _buildInterpretationPrompt(String fromLang, String toLang) {
    final fromLangName = _langNames[fromLang] ?? fromLang;
    final toLangName = _langNames[toLang] ?? toLang;

    return '''
You are an AI assistant for image translation & document interpretation.

Attached is an image or PDF document containing $fromLangName text.

Instructions:
- Carefully extract and analyze the document content.
- If the document has multiple pages, consider all of them.
- Only use information that is fully visible and clearly readable.
- If anything is illegible or incomplete, say "illegible" or "not clearly identifiable".

Output:
Provide a clear summary in $toLangName using valid HTML structure:
- Use paragraphs for explanations.
- Use lists for instructions or key points.
- Use <strong> to highlight important facts (dates, amounts, names).
- Keep output minimal on whitespace.
- Do NOT wrap inside code blocks or markdown.

If nothing can be read, reply only with:
<p><strong>Can't understand the image</strong></p>
''';
  }

  /// Languages the last [processImage] call found in the document, as
  /// two-letter codes (e.g. ["HU", "DE"]); empty when Gemini did not report
  /// them. Lets the Image page refuse a source language the document does
  /// not contain without reading it again (Markus, 2026-10-09).
  List<String> lastDocumentLanguages = const [];

  /// Asked of every analysis so the document's languages come for free with
  /// the result; [takeLanguagesLine] removes the line again before anything
  /// else sees the reply, so the result format is unchanged.
  static const _languagesInstruction = '''

ADDITIONALLY, before everything else, output exactly one line:
LANGUAGES: <codes>
listing every language that makes up a meaningful part of the document's
text, as comma-separated codes from: HU, DE, EN, NL, FR, ES, RU, IT.
Ignore numbers, dates, codes, names and single foreign words. Write
"LANGUAGES: UNKNOWN" if you cannot tell. Then continue with the output
exactly as specified above.
''';

  static final _languagesLine = RegExp(
    r'^[ \t]*LANGUAGES:[ \t]*([A-Za-z, ]*)[ \t]*\r?\n?',
    multiLine: true,
  );

  /// Splits the LANGUAGES line off [reply]; returns the reply without it and
  /// the supported codes it listed.
  @visibleForTesting
  static ({String text, List<String> languages}) takeLanguagesLine(
    String reply,
  ) {
    final match = _languagesLine.firstMatch(reply);
    if (match == null) return (text: reply, languages: const []);
    const supported = ['HU', 'DE', 'EN', 'NL', 'FR', 'ES', 'RU', 'IT'];
    final languages =
        match
            .group(1)!
            .split(',')
            .map((c) => c.trim().toUpperCase())
            .where(supported.contains)
            .toList();
    final text = reply.replaceRange(match.start, match.end, '').trim();
    return (text: text, languages: languages);
  }

  Future<String> processImage({
    required File imageFile,
    required bool translate,
    required bool interpret,
    required String fromLangCode,
    required String toLangCode,
    // Optional page selection for PDFs, e.g. "3" or "2-5". Null = all pages
    // (Markus, 2026-07-15: let the user pick which page of a PDF to
    // translate instead of always doing the whole document).
    String? pdfPages,
  }) async {
    if (!translate && !interpret) {
      throw Exception('Must select at least one: translate or interpret.');
    }

    var prompt =
        interpret
            ? _buildInterpretationPrompt(fromLangCode, toLangCode)
            : _buildTranslationPrompt(fromLangCode, toLangCode);
    if (pdfPages != null && pdfPages.trim().isNotEmpty) {
      prompt =
          '$prompt\nIMPORTANT: Process ONLY page(s) ${pdfPages.trim()} of the '
          'attached document. Ignore every other page completely.';
    }

    final split = takeLanguagesLine(
      await _callGemini('$prompt$_languagesInstruction', imageFile),
    );
    lastDocumentLanguages = split.languages;
    return split.text;
  }

  /// Answers a free-text question about an already-loaded image/PDF (Markus,
  /// 2026-07-23: a "?" button next to a translated document that opens a
  /// modal where the user can type a question about it).
  Future<String> askAboutDocument({
    required File documentFile,
    required String question,
    required String answerLangCode,
    // Same page-restriction convention as processImage's pdfPages.
    String? pdfPages,
  }) async {
    final answerLangName = _langNames[answerLangCode] ?? answerLangCode;
    var prompt = _buildQuestionPrompt(question, answerLangName);
    if (pdfPages != null && pdfPages.trim().isNotEmpty) {
      prompt =
          '$prompt\nBase your answer only on page(s) ${pdfPages.trim()} of '
          'the attached document.';
    }
    return _callGemini(prompt, documentFile);
  }

  /// Translates text segments already extracted from an image into another
  /// target language, without sending the image again (Markus, video of
  /// 2026-09-29: switching the target language re-read the whole image, "the
  /// text was already here"). Returns one translation per entry of
  /// [originals], in order. Billed like any other Gemini call, but only for
  /// the text, so it is much cheaper and faster than [processImage].
  Future<List<String>> retranslateSegments({
    required List<String> originals,
    required String fromLangCode,
    required String toLangCode,
  }) async {
    final fromLangName = _langNames[fromLangCode] ?? fromLangCode;
    final toLangName = _langNames[toLangCode] ?? toLangCode;
    final targetDateFormat = _dateFormats[toLangCode] ?? "YYYY-MM-DD";
    final prompt = '''
You are a translator. Below is a JSON array of $fromLangName text segments taken from a document.

Translate each segment individually into $toLangName.
- Keep the same number of entries, in the same order.
- Convert any dates into $targetDateFormat.
- Do not add explanations.

STRICT OUTPUT FORMAT: return ONLY a JSON array of strings, one translation per input segment, with nothing before or after it.

Segments:
${jsonEncode(originals)}
''';
    var text = await _callGemini(prompt, null);
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    final decoded = jsonDecode(text);
    if (decoded is! List || decoded.length != originals.length) {
      throw const FormatException('Re-translation did not match the segments');
    }
    return decoded.map((e) => e.toString()).toList();
  }

  /// [file] is the image/PDF to attach, or null for a text-only request.
  Future<String> _callGemini(String prompt, File? file) async {
    final reply = await geminiGenerate(
      _model,
      // Was 2048, which a multi-page PDF blows straight through: the
      // model (2.5 flash) spends output budget on internal thinking
      // first, sees almost nothing left for the answer, and bails out
      // with "[]" — which the app then reported as "image not clear"
      // (Markus, 2026-07-15, 9-page PDF; reproduced 1:1 with his file:
      // 1201 thought tokens then a bare [] at 2048, full extraction at
      // a higher cap).
      TextAiRequest(user: prompt, temperature: 0.2, maxOutputTokens: 32768),
      file:
          file == null
              ? null
              : GeminiFile(
                lookupMimeType(file.path) ?? 'image/jpeg',
                await file.readAsBytes(),
              ),
    );

    final result = reply.result;
    TokenBalance.instance.spendFractional(
      geminiWiuCost(
        promptTokens: result.inputTokens,
        outputTokens: result.outputTokens,
      ),
    );

    if (!reply.hasCandidates) {
      // Don't return '' here: the caller treats an empty string as "image
      // not clear", which points the user at their photo when the real
      // problem was the request (safety block, truncation, ...).
      throw Exception('Gemini returned no candidates');
    }
    final text = result.text.trim();
    if (text.isEmpty && reply.finishReason != FinishReason.stop) {
      throw Exception(
        'Gemini returned no text (finishReason: ${reply.finishReason})',
      );
    }
    return text;
  }
}
