import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'gemini_cost.dart';
import 'token_balance.dart';

/// Image translation / interpretation via Gemini vision.
///
/// Drop-in replacement for the old OpenAI-based ChatGptService: same
/// [processImage] signature, so the Image page is unchanged apart from the
/// service it instantiates.
class GeminiImageService {
  GeminiImageService();

  String get _apiKey => dotenv.env['GEMINI_API_KEY']!;
  static const _model = 'gemini-flash-latest';
  String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

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

    return _callGemini(prompt, imageFile);
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
    final requestParts = <Map<String, dynamic>>[
      {"text": prompt},
    ];
    if (file != null) {
      final bytes = await file.readAsBytes();
      requestParts.add({
        "inline_data": {
          "mime_type": lookupMimeType(file.path) ?? 'image/jpeg',
          "data": base64Encode(bytes),
        },
      });
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {"parts": requestParts},
        ],
        // Was 2048, which a multi-page PDF blows straight through: the
        // model (2.5 flash) spends output budget on internal thinking
        // first, sees almost nothing left for the answer, and bails out
        // with "[]" — which the app then reported as "image not clear"
        // (Markus, 2026-07-15, 9-page PDF; reproduced 1:1 with his file:
        // 1201 thought tokens then a bare [] at 2048, full extraction at
        // a higher cap).
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 32768},
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
        outputTokens: usage?['candidatesTokenCount'] as int? ?? 0,
      ),
    );

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // Don't return '' here: the caller treats an empty string as "image
      // not clear", which points the user at their photo when the real
      // problem was the request (safety block, truncation, ...).
      throw Exception(
        'Gemini returned no candidates '
        '(finishReason unknown, promptFeedback: ${data['promptFeedback']})',
      );
    }
    final finishReason = candidates[0]['finishReason'] as String? ?? '';
    final parts = candidates[0]['content']?['parts'] as List?;
    final text =
        (parts == null || parts.isEmpty)
            ? ''
            : (parts[0]['text'] as String? ?? '');
    if (text.trim().isEmpty && finishReason != 'STOP') {
      throw Exception('Gemini returned no text (finishReason: $finishReason)');
    }
    return text.trim();
  }
}
