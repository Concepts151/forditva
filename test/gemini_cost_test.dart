import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/gemini_cost.dart';

void main() {
  group('geminiWiuCost', () {
    test('zero tokens cost nothing', () {
      expect(geminiWiuCost(promptTokens: 0, outputTokens: 0), 0);
    });

    test('applies the +30% fee margin on top of the real cost', () {
      // Markus's own worked example: 300 in / 300 out.
      const realCost = 300 * 0.00012 + 300 * 0.001; // 0.336 WIU
      expect(
        geminiWiuCost(promptTokens: 300, outputTokens: 300),
        closeTo(realCost * 1.30, 1e-9),
      );
    });

    test('billed cost is exactly feeMargin times the raw cost', () {
      const rawInput = 1000 * 0.00012;
      const rawOutput = 500 * 0.001;
      expect(
        geminiWiuCost(promptTokens: 1000, outputTokens: 500),
        closeTo((rawInput + rawOutput) * feeMargin, 1e-9),
      );
    });
  });

  group('billableOutputTokens', () {
    test('adds thinking tokens to the visible answer', () {
      expect(
        billableOutputTokens(prompt: 3500, candidates: 230, thoughts: 3600),
        3830,
      );
    });

    test('derives thinking from the total when only that is known', () {
      expect(
        billableOutputTokens(prompt: 1000, candidates: 200, total: 1700),
        700,
      );
    });

    test('falls back to the visible answer without thinking data', () {
      expect(billableOutputTokens(prompt: 1000, candidates: 200), 200);
      expect(
        billableOutputTokens(prompt: 1000, candidates: 200, total: 1200),
        200,
      );
    });
  });
}
