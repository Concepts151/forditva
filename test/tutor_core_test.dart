import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/tutor/tutor_core.dart';

void main() {
  test('an empty answer means no Hungarian sentence was found', () {
    expect(isEmptyTutorReply('[]'), isTrue);
    expect(isEmptyTutorReply(' [ ] '), isTrue);
    expect(isEmptyTutorReply('```json\n[]\n```'), isTrue);
    expect(
      isEmptyTutorReply('[{"hu": "Jó estét!", "direct": "", "correct": ""}]'),
      isFalse,
    );
    expect(isEmptyTutorReply('not json'), isFalse);
  });

  group('IncrementalJsonArray', () {
    const reply =
        '```json\n[\n  {"hu": "Jó estét!", "direct": "Good evening{Akk}!", '
        '"correct": "Good evening!"},\n'
        '  {"hu": "Hogy vagy \\"ma\\"?", "direct": "how are-you", '
        '"correct": "How are you [today]?"}\n]\n```';

    test('returns each sentence as soon as its closing brace arrives', () {
      final parser = IncrementalJsonArray();
      final got = <String>[];
      // Cut the reply into 7-character pieces, as a stream might.
      for (var i = 0; i < reply.length; i += 7) {
        final end = i + 7 > reply.length ? reply.length : i + 7;
        for (final s in parser.add(reply.substring(i, end))) {
          got.add(s['hu'] as String);
        }
      }
      expect(got, ['Jó estét!', 'Hogy vagy "ma"?']);
    });

    test('a half-written sentence is not returned yet', () {
      final parser = IncrementalJsonArray();
      expect(parser.add('[{"hu": "Jó", "direct": "Go'), isEmpty);
      final done = parser.add('od", "correct": "Good"}, {"hu": "N');
      expect(done.single['correct'], 'Good');
    });

    test('braces and brackets inside text do not end an element early', () {
      final parser = IncrementalJsonArray();
      final done = parser.add('[{"hu": "a } ] b", "x": ["y", {"z": 1}]}]');
      expect(done.single['hu'], 'a } ] b');
    });

    test('an empty array gives nothing', () {
      expect(IncrementalJsonArray().add('[]'), isEmpty);
    });
  });
}
