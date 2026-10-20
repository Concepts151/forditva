import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/translation_prompts.dart';

void main() {
  test('the text is wrapped in tags, line breaks kept', () {
    expect(
      translationUserMessage('Egy.\nKettő.'),
      '<text>\nEgy.\nKettő.\n</text>',
    );
  });

  test('echoed tags are removed', () {
    expect(stripTranslationTags('<text>\nOne.\nTwo.\n</text>'), 'One.\nTwo.');
    expect(stripTranslationTags('  One.  '), 'One.');
  });
}
