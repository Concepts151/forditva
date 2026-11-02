import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/gemini_image_service.dart';

void main() {
  test('the language check reads one code, nothing else', () {
    expect(GeminiImageService.parseDocumentLanguage('DE'), 'DE');
    expect(GeminiImageService.parseDocumentLanguage(' hu\n'), 'HU');
    expect(GeminiImageService.parseDocumentLanguage('DE.'), 'DE');
    expect(GeminiImageService.parseDocumentLanguage('MIXED'), isNull);
    expect(GeminiImageService.parseDocumentLanguage('UNKNOWN'), isNull);
    expect(GeminiImageService.parseDocumentLanguage(''), isNull);
    expect(GeminiImageService.parseDocumentLanguage('PL'), isNull);
  });
}
