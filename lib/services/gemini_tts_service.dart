import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'token_balance.dart';

/// Why read-aloud failed, so the pages can tell the user something useful.
enum TtsFailure {
  /// Switched off on the server (permission-denied): "not available".
  unavailable,

  /// Too many requests (resource-exhausted): try again in a minute.
  busy,

  /// Anything else: network, timeout after the retry, a rejected text.
  failed,
}

class TtsException implements Exception {
  final TtsFailure failure;
  final String detail;
  const TtsException(this.failure, this.detail);

  @override
  String toString() => 'TtsException($failure): $detail';
}

/// Text-to-speech via **Google Cloud TTS** with a NATIVE voice per language
/// (German / Hungarian / English). The previous Gemini TTS used English-centric
/// personas, which made German sound foreign-accented; native de-DE voices fix
/// that.
///
/// Since 2026-10-20 the app no longer calls Google with a key. It calls
/// Alex's Firebase function `synthesizeSpeech` (europe-west1, App Check
/// enforced), which holds the credentials server-side.
///
/// The class name is kept as `GeminiTtsService` so the existing call sites and
/// imports don't need to change.
class GeminiTtsService {
  static final HttpsCallable _synthesize = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  ).httpsCallable(
    'synthesizeSpeech',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
  );

  /// The function rejects texts over 5,000 UTF-8 bytes; longer texts are
  /// split at sentence ends and the parts joined into one MP3.
  static const int _maxBytes = 5000;

  // Native voice per language: [languageCode, voiceName]. Every selectable
  // language (HU/DE + the third-language options) needs an entry, otherwise
  // its text was read with the default (German/Hungarian) voice.
  // All WaveNet ($4/1M chars), not Neural2 ($16/1M): Markus, 2026-07-11,
  // correctness matters more than voice quality, keep TTS cost down.
  // Alex, 2026-10-19: de-B, hu-A, es-B and it-D are no longer in Google's
  // list, so they became de-H, hu-B, es-E and it-F. The function only
  // accepts these eight.
  static const Map<String, List<String>> _voices = {
    'DE': ['de-DE', 'de-DE-Wavenet-H'],
    'HU': ['hu-HU', 'hu-HU-Wavenet-B'],
    'EN': ['en-US', 'en-US-Wavenet-D'],
    'FR': ['fr-FR', 'fr-FR-Wavenet-F'],
    'ES': ['es-ES', 'es-ES-Wavenet-E'],
    'IT': ['it-IT', 'it-IT-Wavenet-F'],
    'NL': ['nl-NL', 'nl-NL-Wavenet-F'],
    'RU': ['ru-RU', 'ru-RU-Wavenet-A'],
  };

  /// WIU cost per character of a given voice, converted from Google Cloud
  /// TTS's real per-character price at the same $0.0025/WIU rate the Gemini
  /// text calls use (Markus, 2026-07-11: TTS wasn't billed at all). Neural2
  /// voices cost $16/1M characters, WaveNet $4/1M.
  double _wiuPerChar(String voiceName) {
    final dollarsPerChar = voiceName.contains('Neural2') ? 16 / 1e6 : 4 / 1e6;
    return dollarsPerChar / 0.0025;
  }

  /// Detects the target language. Prefers an explicit [langCode]; otherwise
  /// parses the language out of the [instructions] the callers pass.
  String _resolveLang(String? langCode, String? instructions) {
    final explicit = (langCode ?? '').toUpperCase();
    if (_voices.containsKey(explicit)) return explicit;
    final i = (instructions ?? '').toLowerCase();
    if (i.contains('german') || i.contains('deutsch')) return 'DE';
    if (i.contains('hungarian') || i.contains('magyar')) return 'HU';
    if (i.contains('english')) return 'EN';
    if (i.contains('french') || i.contains('français')) return 'FR';
    if (i.contains('spanish') || i.contains('español')) return 'ES';
    if (i.contains('italian') || i.contains('italiano')) return 'IT';
    if (i.contains('dutch') || i.contains('nederlands')) return 'NL';
    if (i.contains('russian') || i.contains('русск')) return 'RU';
    return 'DE';
  }

  Future<File> synthesizeSpeech({
    required String text,
    String voice = '', // ignored; kept for call-site compatibility
    String model = '', // ignored; kept for call-site compatibility
    String format = 'mp3',
    String? instructions,
    String? langCode,
  }) async {
    final code = _resolveLang(langCode, instructions);
    final v = _voices[code]!;

    final audio = BytesBuilder(copy: false);
    var characters = 0;
    for (final part in splitForTts(text, _maxBytes)) {
      final r = await _synthesizePart(part, v[0], v[1]);
      audio.add(r.audio);
      characters += r.characters;
    }

    // Billed only once every part came back (Alex: charge WIU only for a
    // successful answer), at the characters Google actually counted.
    TokenBalance.instance.spendFractional(characters * _wiuPerChar(v[1]));

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    // MP3 frames are self-contained, so the parts play back as one file.
    await file.writeAsBytes(audio.takeBytes(), flush: true);
    return file;
  }

  /// One call to the function, with Alex's error rules: unavailable and
  /// deadline-exceeded are retried once; "google_rejected" splits the text
  /// in two and tries each half.
  Future<({Uint8List audio, int characters})> _synthesizePart(
    String text,
    String languageCode,
    String voiceName, {
    bool retried = false,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final result = await _synthesize.call<Map<String, dynamic>>({
        'text': text,
        'languageCode': languageCode,
        'voice': voiceName,
        'audioEncoding': 'MP3',
      });
      debugPrint(
        'TTS call: ${watch.elapsedMilliseconds} ms, '
        '${utf8.encode(text).length} bytes',
      );
      final audioContent = result.data['audioContent'] as String?;
      if (audioContent == null || audioContent.isEmpty) {
        throw const TtsException(TtsFailure.failed, 'no audio in the answer');
      }
      return (
        audio: base64Decode(audioContent),
        characters: (result.data['characters'] as num?)?.toInt() ?? text.length,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'TTS call failed after ${watch.elapsedMilliseconds} ms: '
        '${e.code} ${e.details}',
      );
      switch (e.code) {
        case 'unavailable' || 'deadline-exceeded' when !retried:
          return _synthesizePart(
            text,
            languageCode,
            voiceName,
            retried: true,
          );
        case 'invalid-argument' when _isGoogleRejected(e.details):
          final halves = splitInHalf(text);
          if (halves == null) {
            throw TtsException(TtsFailure.failed, 'google_rejected: $text');
          }
          final a = await _synthesizePart(halves.$1, languageCode, voiceName);
          final b = await _synthesizePart(halves.$2, languageCode, voiceName);
          return (
            audio: Uint8List.fromList([...a.audio, ...b.audio]),
            characters: a.characters + b.characters,
          );
        case 'resource-exhausted':
          throw TtsException(TtsFailure.busy, e.code);
        case 'permission-denied':
          throw TtsException(TtsFailure.unavailable, e.code);
        default:
          throw TtsException(TtsFailure.failed, '${e.code} ${e.details}');
      }
    }
  }

  static bool _isGoogleRejected(Object? details) {
    if (details is Map) return details['reason'] == 'google_rejected';
    return details?.toString().contains('google_rejected') ?? false;
  }
}

/// Splits [text] into parts of at most [maxBytes] UTF-8 bytes, cutting at
/// sentence ends where possible, then at spaces, then anywhere.
@visibleForTesting
List<String> splitForTts(String text, int maxBytes) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return [];
  if (utf8.encode(trimmed).length <= maxBytes) return [trimmed];

  final sentences =
      RegExp(r'[^.!?…\n]+(?:[.!?…]+|\n+|$)\s*')
          .allMatches(trimmed)
          .map((m) => m.group(0)!)
          .toList();

  final parts = <String>[];
  var current = StringBuffer();
  void flush() {
    final s = current.toString().trim();
    if (s.isNotEmpty) parts.add(s);
    current = StringBuffer();
  }

  for (final sentence in sentences) {
    if (utf8.encode('$current$sentence').length <= maxBytes) {
      current.write(sentence);
      continue;
    }
    flush();
    if (utf8.encode(sentence).length <= maxBytes) {
      current.write(sentence);
    } else {
      parts.addAll(_splitLong(sentence, maxBytes));
    }
  }
  flush();
  return parts;
}

/// A single sentence over the limit: cut at spaces, or hard-cut a word
/// that is itself too long.
List<String> _splitLong(String sentence, int maxBytes) {
  final parts = <String>[];
  var current = '';
  for (final word in sentence.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final candidate = current.isEmpty ? word : '$current $word';
    if (utf8.encode(candidate).length <= maxBytes) {
      current = candidate;
      continue;
    }
    if (current.isNotEmpty) parts.add(current);
    current = word;
    while (utf8.encode(current).length > maxBytes) {
      var cut = current.length;
      while (utf8.encode(current.substring(0, cut)).length > maxBytes) {
        cut--;
      }
      parts.add(current.substring(0, cut));
      current = current.substring(cut);
    }
  }
  if (current.isNotEmpty) parts.add(current);
  return parts;
}

/// Splits [text] near its middle, preferring a sentence end, then a space.
/// Null when it is too short to split.
@visibleForTesting
(String, String)? splitInHalf(String text) {
  if (text.length < 2) return null;
  final mid = text.length ~/ 2;
  int? best;
  for (final pattern in [RegExp(r'[.!?…]\s'), RegExp(r'\s')]) {
    for (final m in pattern.allMatches(text)) {
      final at = m.end;
      if (at <= 0 || at >= text.length) continue;
      if (best == null || (at - mid).abs() < (best - mid).abs()) best = at;
    }
    if (best != null) break;
  }
  final cut = best ?? mid;
  final a = text.substring(0, cut).trim();
  final b = text.substring(cut).trim();
  if (a.isEmpty || b.isEmpty) return null;
  return (a, b);
}
