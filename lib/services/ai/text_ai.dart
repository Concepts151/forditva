import 'dart:convert';

import 'package:http/http.dart' as http;

import '../gemini_cost.dart';
import 'ai_models.dart';

/// One text-only request (no images or audio), the same for every provider.
class TextAiRequest {
  /// Instructions; null sends only [user].
  final String? system;
  final String user;

  /// Ask for a JSON reply.
  final bool json;

  /// Null leaves the provider's default.
  final double? temperature;

  /// False turns thinking off (Gemini: thinkingBudget 0; DeepSeek:
  /// thinking disabled). True leaves the model's default thinking on.
  final bool thinking;

  final int? maxOutputTokens;

  const TextAiRequest({
    this.system,
    required this.user,
    this.json = false,
    this.temperature,
    this.thinking = true,
    this.maxOutputTokens,
  });
}

/// The reply text plus the token counts the WIU charge needs.
class TextAiResult {
  final String text;

  /// The model that actually answered, as the provider names it.
  final String modelVersion;
  final int inputTokens;
  final int cachedInputTokens;

  /// Visible answer plus thinking tokens: both are billed as output.
  final int outputTokens;

  const TextAiResult({
    required this.text,
    required this.modelVersion,
    required this.inputTokens,
    required this.outputTokens,
    this.cachedInputTokens = 0,
  });
}

/// Sends [request] to [model] and returns the reply. Pure Dart (no Flutter),
/// so the comparison tools in tool/ can use it. The app itself sends Gemini
/// requests through Firebase AI Logic (gemini_firebase.dart) and does not
/// call this. Throws on any HTTP error.
Future<TextAiResult> generateText(
  AiModel model,
  TextAiRequest request, {
  required String apiKey,
  http.Client? client,
  String deepseekBaseUrl = 'https://api.deepseek.com',
}) {
  switch (model.provider) {
    case AiProvider.gemini:
      return _gemini(model, request, apiKey, client);
    case AiProvider.deepseek:
      return _openAiStyle(model, request, apiKey, client, deepseekBaseUrl);
  }
}

Future<http.Response> _post(
  http.Client? client,
  Uri uri,
  Map<String, String> headers,
  Object body,
) {
  final h = {'Content-Type': 'application/json', ...headers};
  final b = jsonEncode(body);
  return client != null
      ? client.post(uri, headers: h, body: b)
      : http.post(uri, headers: h, body: b);
}

Future<TextAiResult> _gemini(
  AiModel model,
  TextAiRequest r,
  String apiKey,
  http.Client? client,
) async {
  final response = await _post(
    client,
    Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${model.id}:generateContent',
    ),
    {'x-goog-api-key': apiKey},
    {
      if (r.system != null)
        'systemInstruction': {
          'parts': [
            {'text': r.system},
          ],
        },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': r.user},
          ],
        },
      ],
      'generationConfig': {
        if (r.temperature != null) 'temperature': r.temperature,
        if (r.json) 'responseMimeType': 'application/json',
        if (r.maxOutputTokens != null) 'maxOutputTokens': r.maxOutputTokens,
        if (!r.thinking && model.thinkingControl)
          'thinkingConfig': {'thinkingBudget': 0},
      },
    },
  );
  if (response.statusCode != 200) {
    throw Exception('Gemini error ${response.statusCode}: ${response.body}');
  }
  return parseGeminiResponse(
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    model.id,
  );
}

/// Reads text and token counts from a Gemini generateContent response.
/// Thought parts are skipped; thinking tokens count as output.
TextAiResult parseGeminiResponse(Map<String, dynamic> data, String modelId) {
  final usage = data['usageMetadata'] as Map<String, dynamic>?;
  final prompt = usage?['promptTokenCount'] as int? ?? 0;
  final parts = data['candidates']?[0]?['content']?['parts'] as List?;
  final text = StringBuffer();
  for (final p in parts ?? const []) {
    if (p is Map && p['thought'] != true && p['text'] is String) {
      text.write(p['text']);
    }
  }
  return TextAiResult(
    text: text.toString(),
    modelVersion: data['modelVersion'] as String? ?? modelId,
    inputTokens: prompt,
    outputTokens: billableOutputTokens(
      prompt: prompt,
      candidates: usage?['candidatesTokenCount'] as int? ?? 0,
      thoughts: usage?['thoughtsTokenCount'] as int?,
      total: usage?['totalTokenCount'] as int?,
    ),
  );
}

Future<TextAiResult> _openAiStyle(
  AiModel model,
  TextAiRequest r,
  String apiKey,
  http.Client? client,
  String baseUrl,
) async {
  final response = await _post(
    client,
    Uri.parse('$baseUrl/chat/completions'),
    {'Authorization': 'Bearer $apiKey'},
    {
      'model': model.id,
      'messages': [
        if (r.system != null) {'role': 'system', 'content': r.system},
        {'role': 'user', 'content': r.user},
      ],
      if (r.temperature != null) 'temperature': r.temperature,
      // No response_format: DeepSeek's JSON mode only allows an object at
      // the top, so the Tutor's array answers came back as one object in
      // 19 of 40 Mode 1 runs; with the prompt alone all 40 were proper
      // arrays (benchmark 2026-10-12). The prompts already demand JSON.
      if (r.maxOutputTokens != null) 'max_tokens': r.maxOutputTokens,
      'thinking': {'type': r.thinking ? 'enabled' : 'disabled'},
    },
  );
  if (response.statusCode != 200) {
    throw Exception('DeepSeek error ${response.statusCode}: ${response.body}');
  }
  return parseOpenAiStyleResponse(
    jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    model.id,
  );
}

/// Reads text and token counts from an OpenAI-style chat completion.
/// completion_tokens already includes reasoning tokens.
TextAiResult parseOpenAiStyleResponse(
  Map<String, dynamic> data,
  String modelId,
) {
  final usage = data['usage'] as Map<String, dynamic>?;
  final cached =
      usage?['prompt_cache_hit_tokens'] as int? ??
      usage?['prompt_tokens_details']?['cached_tokens'] as int? ??
      0;
  return TextAiResult(
    text: data['choices']?[0]?['message']?['content'] as String? ?? '',
    modelVersion: data['model'] as String? ?? modelId,
    inputTokens: usage?['prompt_tokens'] as int? ?? 0,
    cachedInputTokens: cached,
    outputTokens: usage?['completion_tokens'] as int? ?? 0,
  );
}
