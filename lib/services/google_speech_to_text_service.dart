import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GoogleSpeechToTextService {
  final String apiKey;

  GoogleSpeechToTextService(this.apiKey);

  /// Sends [audioFile] (16 kHz LINEAR16 WAV) to Cloud STT and returns the
  /// raw `results` list (empty when nothing was recognized).
  Future<List<dynamic>> _recognize(File audioFile, String languageCode) async {
    final bytes = await audioFile.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final url = 'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey';
    final requestBody = {
      "config": {
        "encoding": "LINEAR16",
        "sampleRateHertz": 16000,
        "languageCode": languageCode,
        // Without this Cloud STT returns one unpunctuated block. Works for
        // en/de (also turns a spoken "Punkt" into "."); Google does not
        // punctuate hu-HU on any v1 model, see [_punctuateHungarian].
        "enableAutomaticPunctuation": true,
      },
      "audio": {"content": base64Audio},
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Google STT Error: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return (data['results'] as List<dynamic>?) ?? const [];
  }

  /// Cloud STT splits longer audio into consecutive results; join them all
  /// so nothing after the first segment is dropped.
  static String _joinTranscripts(List<dynamic> results) => results
      .map((r) => (r['alternatives']?[0]?['transcript'] ?? '') as String)
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .join(' ');

  Future<String?> transcribe(
    File audioFile, {
    String languageCode = 'en-US',
  }) async {
    final results = await _recognize(audioFile, languageCode);
    return _punctuateIfNeeded(_joinTranscripts(results), languageCode);
  }

  /// Like [transcribe] but also returns the recognizer's confidence (0–1).
  /// When the wrong language is spoken for the requested [languageCode],
  /// confidence comes back low — we use that to prompt the user.
  Future<({String text, double confidence})> transcribeWithConfidence(
    File audioFile, {
    String languageCode = 'en-US',
  }) async {
    final results = await _recognize(audioFile, languageCode);
    if (results.isEmpty) {
      return (text: '', confidence: 0.0);
    }
    final confidences = results
        .map((r) => (r['alternatives']?[0]?['confidence'] ?? 0.0) as num)
        .toList();
    final avg =
        confidences.fold<double>(0, (a, c) => a + c) / confidences.length;
    final text = await _punctuateIfNeeded(
      _joinTranscripts(results),
      languageCode,
    );
    return (text: text, confidence: avg);
  }

  Future<String> _punctuateIfNeeded(String text, String languageCode) async {
    if (text.isEmpty || !languageCode.toLowerCase().startsWith('hu')) {
      return text;
    }
    return _punctuateHungarian(text);
  }

  /// Cloud STT v1 returns Hungarian without any punctuation (no v1 model
  /// supports it, and v2/Chirp needs OAuth instead of an API key), so ask
  /// Gemini to add only punctuation and capitalization. Not billed in WIU:
  /// a few dozen tokens, a fraction of a cent. Any failure, or a reply that
  /// changed the words, falls back to the unpunctuated transcript.
  static Future<String> _punctuateHungarian(String text) async {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) return text;
    const prompt =
        'Add punctuation and capitalization to this Hungarian '
        'speech-recognition transcript.\n'
        'Do not add, remove, reorder or change any words. Only insert '
        'punctuation marks and fix capitalization.\n'
        'Return only the corrected text, nothing else.\n\n'
        'Transcript:\n';
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              'gemini-flash-latest:generateContent?key=$key',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': '$prompt$text'},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0,
                // No thinking: ~2s instead of 6-12s for this trivial task.
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return text;
      final data = jsonDecode(response.body);
      final out =
          ((data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '')
                  as String)
              .trim();
      return sameWords(text, out) ? out : text;
    } catch (e) {
      debugPrint('Hungarian punctuation pass failed: $e');
      return text;
    }
  }

  /// True when [a] and [b] contain the same words in the same order,
  /// ignoring punctuation and case.
  @visibleForTesting
  static bool sameWords(String a, String b) {
    List<String> words(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return listEquals(words(a), words(b));
  }
}
