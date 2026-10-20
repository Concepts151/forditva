import '../gemini_cost.dart';

/// Who answers a text request. Gemini uses Google's REST API; DeepSeek uses
/// the OpenAI-style chat API, which many other hosts also speak (Markus,
/// 2026-10-12: the provider must be selectable in code).
enum AiProvider { gemini, deepseek }

/// A model the app can send text requests to, with its price per 1M tokens
/// in USD. [cachedInputPerM] applies to input the provider served from its
/// cache (DeepSeek reports it; Gemini requests here are billed without it).
class AiModel {
  final AiProvider provider;
  final String id;
  final double inputPerM;
  final double cachedInputPerM;
  final double outputPerM;

  /// False for models that reject a request to switch thinking off
  /// (Gemini 3.5 Flash-Lite answers 400 to thinkingBudget 0; it does not
  /// think anyway). The setting is then left out.
  final bool thinkingControl;

  const AiModel({
    required this.provider,
    required this.id,
    required this.inputPerM,
    required this.outputPerM,
    double? cachedInputPerM,
    this.thinkingControl = true,
  }) : cachedInputPerM = cachedInputPerM ?? inputPerM;
}

/// The models the routes in ai_router.dart can choose from.
///
/// Gemini entries keep the Gemini 2.5 Flash prices behind [geminiWiuCost]
/// ($0.30 / $2.50), so charges stay exactly as before. Google now serves
/// 3.8 Flash ($0.75 / $3.75) for the -latest alias; changing that charge is
/// Markus's decision (asked 2026-10-12).
///
/// DeepSeek entries use the peak price from api-docs.deepseek.com
/// (2026-10-12); off-peak is half, so charging peak never undercharges.
class AiModels {
  static const geminiFlashLite = AiModel(
    provider: AiProvider.gemini,
    id: 'gemini-flash-lite-latest',
    inputPerM: 0.30,
    outputPerM: 2.50,
    thinkingControl: false,
  );

  static const geminiFlash = AiModel(
    provider: AiProvider.gemini,
    id: 'gemini-flash-latest',
    inputPerM: 0.30,
    outputPerM: 2.50,
  );

  static const deepseekFlash = AiModel(
    provider: AiProvider.deepseek,
    id: 'deepseek-flash',
    inputPerM: 0.30,
    cachedInputPerM: 0.006,
    outputPerM: 1.20,
  );

  static const deepseekPro = AiModel(
    provider: AiProvider.deepseek,
    id: 'deepseek-v4-pro',
    inputPerM: 1.32,
    cachedInputPerM: 0.044,
    outputPerM: 3.96,
  );
}

/// WIU price of one response: the model's real cost at $0.0025 per WIU,
/// plus the [feeMargin]. [inputTokens] includes [cachedInputTokens];
/// [outputTokens] includes thinking tokens.
double aiWiuCost(
  AiModel model, {
  required int inputTokens,
  int cachedInputTokens = 0,
  required int outputTokens,
}) {
  final uncached = inputTokens - cachedInputTokens;
  final dollars =
      (uncached * model.inputPerM +
          cachedInputTokens * model.cachedInputPerM +
          outputTokens * model.outputPerM) /
      1e6;
  return dollars / 0.0025 * feeMargin;
}
