import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;

import '../gemini_cost.dart';
import 'ai_models.dart';
import 'text_ai.dart';

/// A photo, PDF or text file sent along with a Gemini request.
class GeminiFile {
  final String mimeType;
  final Uint8List bytes;
  const GeminiFile(this.mimeType, this.bytes);
}

/// The reply of [geminiGenerate]: text and token counts, plus what the
/// photo/PDF path needs to tell a failed request from an empty document.
class GeminiReply {
  final TextAiResult result;
  final bool hasCandidates;
  final FinishReason? finishReason;
  const GeminiReply(this.result, this.hasCandidates, this.finishReason);
}

/// Sends [request] (and [file], if any) to [model] through Firebase AI
/// Logic. No Gemini key is in the app: Firebase holds it, and App Check
/// (Play Integrity) proves the request comes from the genuine app.
/// [client] lets the caller abandon the request by closing it.
/// Charges nothing; the caller bills the token counts.
Future<GeminiReply> geminiGenerate(
  AiModel model,
  TextAiRequest request, {
  GeminiFile? file,
  http.Client? client,
}) async {
  final generativeModel = FirebaseAI.googleAI().generativeModel(
    model: model.id,
    systemInstruction:
        request.system != null ? Content.system(request.system!) : null,
    generationConfig: GenerationConfig(
      temperature: request.temperature,
      maxOutputTokens: request.maxOutputTokens,
      responseMimeType: request.json ? 'application/json' : null,
      thinkingConfig:
          !request.thinking && model.thinkingControl
              ? ThinkingConfig.withThinkingBudget(0)
              : null,
    ),
    httpClient: client,
  );
  final response = await generativeModel.generateContent([
    Content.multi([
      TextPart(request.user),
      if (file != null) InlineDataPart(file.mimeType, file.bytes),
    ]),
  ]);

  final usage = response.usageMetadata;
  final prompt = usage?.promptTokenCount ?? 0;
  return GeminiReply(
    TextAiResult(
      text: response.text ?? '',
      modelVersion: model.id,
      inputTokens: prompt,
      outputTokens: billableOutputTokens(
        prompt: prompt,
        candidates: usage?.candidatesTokenCount ?? 0,
        thoughts: usage?.thoughtsTokenCount,
        total: usage?.totalTokenCount,
      ),
    ),
    response.candidates.isNotEmpty,
    response.candidates.isNotEmpty
        ? response.candidates.first.finishReason
        : null,
  );
}
