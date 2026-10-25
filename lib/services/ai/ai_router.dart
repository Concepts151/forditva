import 'package:http/http.dart' as http;

import '../token_balance.dart';
import 'ai_models.dart';
import 'gemini_firebase.dart';
import 'text_ai.dart';

export 'ai_models.dart';
export 'text_ai.dart' show TextAiRequest, TextAiResult;

/// The text-only jobs whose model can be chosen per job. Photos, PDFs,
/// voice input and read-aloud are not here: they stay on Google.
enum AiTask {
  /// Plain text translation (Conversation, edit panel, documents).
  translate,

  /// Explain mode on the Text page (older single-prompt explanation).
  explain,

  /// "Which language is this?" checks before translating.
  detectLanguage,

  /// The three Tutor tabs.
  tutor,

  /// Splitting a text into sentences for the Tutor's sentence picker.
  tutorSentences,
}

/// The Gemini model for each job. Markus, 2026-10-22: all AI runs in the EU,
/// so every job stays on Gemini; DeepSeek (text processed in China) was
/// removed from the app.
const Map<AiTask, AiModel> aiRoutes = {
  AiTask.translate: AiModels.geminiFlashLite,
  AiTask.explain: AiModels.geminiFlashLite,
  AiTask.detectLanguage: AiModels.geminiFlashLite,
  AiTask.tutor: AiModels.geminiFlash,
  AiTask.tutorSentences: AiModels.geminiFlash,
};

/// Runs [request] on the model routed for [task] and charges its WIU price.
/// [client] lets the caller cancel the request (the Tutor closes it to
/// abandon one).
Future<TextAiResult> runAiTask(
  AiTask task,
  TextAiRequest request, {
  http.Client? client,
}) async {
  final model = aiRoutes[task]!;
  final result = (await geminiGenerate(model, request, client: client)).result;
  _charge(model, result);
  return result;
}

void _charge(AiModel model, TextAiResult result) {
  TokenBalance.instance.spendFractional(
    aiWiuCost(
      model,
      inputTokens: result.inputTokens,
      cachedInputTokens: result.cachedInputTokens,
      outputTokens: result.outputTokens,
    ),
  );
}
