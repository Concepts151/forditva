import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/gemini_tts_service.dart';

int bytes(String s) => utf8.encode(s).length;

void main() {
  group('splitForTts', () {
    test('short text stays one part', () {
      expect(splitForTts('  Hol van a posta?  ', 5000), ['Hol van a posta?']);
    });

    test('empty text gives no parts', () {
      expect(splitForTts('   ', 5000), isEmpty);
    });

    test('cuts at sentence ends and keeps every part under the limit', () {
      // Hungarian accents are 2 bytes in UTF-8, so the byte limit bites
      // before the character count does.
      const sentence = 'Árvíztűrő tükörfúrógép működik. ';
      final text = sentence * 300;
      final parts = splitForTts(text, 5000);
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(bytes(p), lessThanOrEqualTo(5000));
        expect(p.endsWith('.'), isTrue);
      }
      expect(parts.join(' '), text.trim());
    });

    test('one sentence over the limit is cut at spaces', () {
      final text = List.filled(2000, 'szó').join(' ');
      final parts = splitForTts(text, 1000);
      for (final p in parts) {
        expect(bytes(p), lessThanOrEqualTo(1000));
      }
      expect(parts.join(' '), text);
    });

    test('a single word over the limit is hard-cut', () {
      final text = 'a' * 2500;
      final parts = splitForTts(text, 1000);
      expect(parts.map((p) => p.length), [1000, 1000, 500]);
    });
  });

  group('splitInHalf', () {
    test('prefers the sentence end nearest the middle', () {
      expect(
        splitInHalf('Erster Satz. Zweiter Satz. Dritter.'),
        ('Erster Satz.', 'Zweiter Satz. Dritter.'),
      );
    });

    test('falls back to a space', () {
      expect(splitInHalf('eins zwei drei vier'), ('eins zwei', 'drei vier'));
    });

    test('a single character cannot be split', () {
      expect(splitInHalf('a'), isNull);
    });
  });
}
