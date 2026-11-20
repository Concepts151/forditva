import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/translation_prompts.dart';

void main() {
  test('the text is wrapped in tags, line breaks kept', () {
    expect(
      translationUserMessage('Egy.\nKettő.'),
      '<text>\nEgy.\nKettő.\n</text>',
    );
  });

  test('Markus\'s November prompt, languages filled in', () {
    final p = translationSystemPrompt('DE', 'HU');
    expect(p, startsWith('You are FORDITVA'));
    expect(p, contains('from DE into HU.'));
    expect(p, contains('when grammatically required by HU;'));
    expect(p, contains('META-LANGUAGE RULE'));
    expect(p, isNot(contains('{fromLang}')));
    expect(p, isNot(contains('{toLang}')));
  });

  test('echoed tags are removed', () {
    expect(stripTranslationTags('<text>\nOne.\nTwo.\n</text>'), 'One.\nTwo.');
    expect(stripTranslationTags('  One.  '), 'One.');
  });
}
