import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../token_balance.dart';
import 'ai_models.dart';
import 'deepseek_firebase.dart';
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

/// The Gemini model for each job. It answers every job when DeepSeek is
/// off, and is the fallback when DeepSeek fails.
const Map<AiTask, AiModel> aiRoutes = {
  AiTask.translate: AiModels.geminiFlashLite,
  AiTask.explain: AiModels.geminiFlashLite,
  AiTask.detectLanguage: AiModels.geminiFlash,
  AiTask.tutor: AiModels.geminiFlash,
  AiTask.tutorSentences: AiModels.geminiFlash,
};

/// Jobs that try DeepSeek first (Markus, 2026-10-12: translations and the
/// Tutor; photos and speech stay on Gemini). Change this set to move a job.
const Set<AiTask> deepseekTasks = {
  AiTask.translate,
  AiTask.tutor,
  AiTask.tutorSentences,
};

/// DeepSeek runs only in builds made with `--dart-define=DEEPSEEK=true`.
/// Alex and Markus, 2026-10-21: no DeepSeek in a user build until Markus
/// confirms the privacy policy update (DeepSeek processes the text in
/// China). Test builds may use it.
const bool deepseekEnabled = bool.fromEnvironment('DEEPSEEK');

/// Set when the function reports an empty balance or that it was switched
/// off; DeepSeek then stays off until the app restarts.
bool _deepseekOff = false;

/// Runs [request] on the model routed for [task] and charges its WIU price.
/// DeepSeek jobs fall back to the job's Gemini model on any DeepSeek error;
/// only the model that answered is charged. [client] lets the caller cancel
/// a Gemini request (the Tutor closes it to abandon one); a DeepSeek call
/// cannot be cancelled and still finishes.
Future<TextAiResult> runAiTask(
  AiTask task,
  TextAiRequest request, {
  http.Client? client,
}) async {
  if (deepseekEnabled &&
      !_deepseekOff &&
      deepseekTasks.contains(task) &&
      deepseekAccepts(request)) {
    try {
      final result = await deepseekGenerate(AiModels.deepseekFlash, request);
      _charge(AiModels.deepseekFlash, result);
      return result;
    } on DeepseekException catch (e) {
      if (e.failure == DeepseekFailure.disabled) _deepseekOff = true;
      debugPrint('DeepSeek -> Gemini for ${task.name} (${e.code})');
    }
  }
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
