import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/google_speech_to_text_service.dart';

void main() {
  group('GoogleSpeechToTextService.sameWords', () {
    test('accepts added punctuation and capitalization', () {
      expect(
        GoogleSpeechToTextService.sameWords(
          'ma Szép az idő szeretnék sétálni a parkban',
          'Ma szép az idő. Szeretnék sétálni a parkban!',
        ),
        isTrue,
      );
    });

    test('rejects a changed, added or dropped word', () {
      const raw = 'tudnál vigyázni a gyerekekre';
      expect(
        GoogleSpeechToTextService.sameWords(raw, 'Tudnál vigyázni a gyerekre?'),
        isFalse,
      );
      expect(
        GoogleSpeechToTextService.sameWords(
          raw,
          'Kérlek, tudnál vigyázni a gyerekekre?',
        ),
        isFalse,
      );
      expect(
        GoogleSpeechToTextService.sameWords(raw, 'Tudnál vigyázni?'),
        isFalse,
      );
    });
  });
}
