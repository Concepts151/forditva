import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/ai/deepseek_firebase.dart';
import 'package:forditva/services/ai/text_ai.dart';

void main() {
  test('requests up to 100,000 UTF-8 bytes go to DeepSeek', () {
    // "ő" is 2 bytes in UTF-8.
    expect(
      deepseekAccepts(TextAiRequest(system: 'a' * 50000, user: 'ő' * 25000)),
      isTrue,
    );
    expect(
      deepseekAccepts(TextAiRequest(system: 'a' * 50000, user: 'ő' * 25001)),
      isFalse,
    );
    expect(deepseekAccepts(TextAiRequest(user: 'ő' * 50001)), isFalse);
  });
}
