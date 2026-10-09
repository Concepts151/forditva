import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/gemini_image_service.dart';

void main() {
  group('GeminiImageService.takeLanguagesLine', () {
    test('splits the line off a JSON reply', () {
      final r = GeminiImageService.takeLanguagesLine(
        'LANGUAGES: HU, DE\n[{"o": "alma", "t": "Apfel"}]',
      );
      expect(r.languages, ['HU', 'DE']);
      expect(r.text, '[{"o": "alma", "t": "Apfel"}]');
    });

    test('finds the line inside a code fence', () {
      final r = GeminiImageService.takeLanguagesLine(
        '```json\nLANGUAGES: EN\n[]\n```',
      );
      expect(r.languages, ['EN']);
      expect(r.text, '```json\n[]\n```');
    });

    test('UNKNOWN and unsupported codes give no languages', () {
      expect(
        GeminiImageService.takeLanguagesLine('LANGUAGES: UNKNOWN\n<p>x</p>')
            .languages,
        isEmpty,
      );
      expect(
        GeminiImageService.takeLanguagesLine('LANGUAGES: PT\n[]').languages,
        isEmpty,
      );
    });

    test('a reply without the line is left untouched', () {
      final r = GeminiImageService.takeLanguagesLine('<p>Hallo</p>');
      expect(r.languages, isEmpty);
      expect(r.text, '<p>Hallo</p>');
    });
  });
}
