import 'package:flutter_dotenv/flutter_dotenv.dart';
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

/// Which model answers each job. Change a line here to move a job to
/// another model or provider (Markus, 2026-10-12). All Gemini until the
/// Gemini/DeepSeek comparison is decided.
const Map<AiTask, AiModel> aiRoutes = {
  AiTask.translate: AiModels.geminiFlashLite,
  AiTask.explain: AiModels.geminiFlashLite,
  AiTask.detectLanguage: AiModels.geminiFlash,
  AiTask.tutor: AiModels.geminiFlash,
  AiTask.tutorSentences: AiModels.geminiFlash,
};

/// DeepSeek's key. Not in the shipped .env (2026-10-20): DeepSeek goes
/// through a Firebase function once Alex adds it. Gemini needs none in the
/// app: it goes through Firebase AI Logic.
String _deepseekKey() {
  final key = dotenv.env['DEEPSEEK_API_KEY']?.trim() ?? '';
  if (key.isEmpty) throw StateError('DEEPSEEK_API_KEY is not set');
  return key;
}

/// Runs [request] on the model routed for [task] and charges its WIU price.
/// [client] lets the caller cancel (the Tutor closes it to abandon a
/// request).
Future<TextAiResult> runAiTask(
  AiTask task,
  TextAiRequest request, {
  http.Client? client,
}) async {
  final model = aiRoutes[task]!;
  final result = switch (model.provider) {
    AiProvider.gemini =>
      (await geminiGenerate(model, request, client: client)).result,
    AiProvider.deepseek => await generateText(
      model,
      request,
      apiKey: _deepseekKey(),
      client: client,
    ),
  };
  TokenBalance.instance.spendFractional(
    aiWiuCost(
      model,
      inputTokens: result.inputTokens,
      cachedInputTokens: result.cachedInputTokens,
      outputTokens: result.outputTokens,
    ),
  );
  return result;
}
