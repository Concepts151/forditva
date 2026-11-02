import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/ai/ai_models.dart';
import 'package:forditva/services/ai/text_ai.dart';
import 'package:forditva/services/gemini_cost.dart';
import 'package:forditva/tutor/tutor_core.dart';

void main() {
  group('aiWiuCost', () {
    test('Gemini models charge exactly what geminiWiuCost charged', () {
      for (final model in [AiModels.geminiFlash, AiModels.geminiFlashLite]) {
        expect(
          aiWiuCost(model, inputTokens: 2000, outputTokens: 5000),
          closeTo(
            geminiWiuCost(promptTokens: 2000, outputTokens: 5000),
            1e-9,
          ),
        );
      }
    });

    test('DeepSeek charges its peak price plus the margin', () {
      // 2,000 in / 5,000 out at $0.30 / $1.20 per 1M = $0.0066.
      expect(
        aiWiuCost(AiModels.deepseekFlash, inputTokens: 2000, outputTokens: 5000),
        closeTo(0.0066 / 0.0025 * feeMargin, 1e-9),
      );
    });

    test('cached input is charged at the cache price', () {
      // 1,500 of 2,000 input tokens from the cache at $0.006 per 1M.
      const dollars = (500 * 0.30 + 1500 * 0.006 + 1000 * 1.20) / 1e6;
      expect(
        aiWiuCost(
          AiModels.deepseekFlash,
          inputTokens: 2000,
          cachedInputTokens: 1500,
          outputTokens: 1000,
        ),
        closeTo(dollars / 0.0025 * feeMargin, 1e-9),
      );
    });
  });

  group('response parsing', () {
    test('Gemini: skips thought parts and bills thinking as output', () {
      final r = parseGeminiResponse({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'thinking...', 'thought': true},
                {'text': 'Szia'},
              ],
            },
          },
        ],
        'usageMetadata': {
          'promptTokenCount': 40,
          'candidatesTokenCount': 2,
          'thoughtsTokenCount': 100,
          'totalTokenCount': 142,
        },
        'modelVersion': 'gemini-3.8-flash',
      }, 'gemini-flash-latest');
      expect(r.text, 'Szia');
      expect(r.inputTokens, 40);
      expect(r.outputTokens, 102);
      expect(r.modelVersion, 'gemini-3.8-flash');
    });

    test('DeepSeek: reads text, cache hits and output tokens', () {
      final r = parseOpenAiStyleResponse({
        'model': 'deepseek-flash',
        'choices': [
          {
            'message': {'content': '{"t": "Szia"}'},
          },
        ],
        'usage': {
          'prompt_tokens': 107,
          'completion_tokens': 1039,
          'prompt_cache_hit_tokens': 64,
          'prompt_cache_miss_tokens': 43,
          'completion_tokens_details': {'reasoning_tokens': 997},
        },
      }, 'deepseek-flash');
      expect(r.text, '{"t": "Szia"}');
      expect(r.inputTokens, 107);
      expect(r.cachedInputTokens, 64);
      expect(r.outputTokens, 1039);
    });
  });

  group('parseTutorArray', () {
    test('accepts a plain array', () {
      expect(parseTutorArray('[{"hu": "a"}]'), [
        {'hu': 'a'},
      ]);
    });

    test('unwraps an object holding a single array', () {
      expect(parseTutorArray('{"sentences": [{"hu": "a"}]}'), [
        {'hu': 'a'},
      ]);
    });

    test('treats a single sentence object as a one-item array', () {
      expect(parseTutorArray('{"hu": "a", "items": [{"term": "x"}]}'), [
        {
          'hu': 'a',
          'items': [
            {'term': 'x'},
          ],
        },
      ]);
    });

    test('rejects an object with no or several arrays', () {
      expect(parseTutorArray('{"x": "a"}'), isNull);
      expect(parseTutorArray('{"a": [{"x": 1}], "b": [{"y": 2}]}'), isNull);
    });
  });
}
