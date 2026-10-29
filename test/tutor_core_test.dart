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
}
