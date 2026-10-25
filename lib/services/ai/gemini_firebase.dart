import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../gemini_cost.dart';
import 'ai_models.dart';
import 'text_ai.dart';

/// Where Gemini runs. Markus, 2026-10-22: all AI in the EU only, through the
/// Vertex AI Gemini API. Alex enabled Vertex AI in the Firebase project and
/// chose the "eu" multi-region (2026-10-23). The SDK's own default is
/// "global", which is not EU, so the location is always passed.
const geminiLocation = 'eu';

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
/// Logic on Vertex AI in [geminiLocation]. No Gemini key is in the app:
/// Firebase holds the access, and App Check (Play Integrity) proves the
/// request comes from the genuine app. [client] lets the caller abandon the
/// request by closing it. Charges nothing; the caller bills the token counts.
Future<GeminiReply> geminiGenerate(
  AiModel model,
  TextAiRequest request, {
  GeminiFile? file,
  http.Client? client,
}) async {
  // Debug builds log each request URL, so the location in use can be read
  // from the phone's log.
  final ownClient = kDebugMode && client == null ? http.Client() : null;
  final httpClient =
      kDebugMode ? _RequestLogClient(client ?? ownClient!) : client;
  try {
    final generativeModel = FirebaseAI.agentPlatform(
      location: geminiLocation,
    ).generativeModel(
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
      httpClient: httpClient,
    );
    final response = await generativeModel.generateContent([
      Content.multi([
        TextPart(request.user),
        if (file != null) InlineDataPart(file.mimeType, file.bytes),
      ]),
    ]);

    final usage = response.usageMetadata;
    final prompt = usage?.promptTokenCount ?? 0;
    if (kDebugMode) {
      debugPrint(
        'Gemini ${model.id}: $prompt in, '
        '${usage?.candidatesTokenCount} out, '
        '${usage?.thoughtsTokenCount} thinking',
      );
    }
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
  } finally {
    ownClient?.close();
  }
}

/// Logs the method, URL and status of each request it passes on (debug
/// builds only). Closing it is left to the owner of [_inner].
class _RequestLogClient extends http.BaseClient {
  final http.Client _inner;
  _RequestLogClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final watch = Stopwatch()..start();
    final response = await _inner.send(request);
    debugPrint(
      'Gemini request: ${request.method} ${request.url} '
      '-> ${response.statusCode} in ${watch.elapsedMilliseconds} ms',
    );
    return response;
  }
}
