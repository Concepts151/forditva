import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'ai_models.dart';
import 'text_ai.dart';

/// Why a DeepSeek call did not answer. Every case falls back to Gemini.
enum DeepseekFailure {
  /// This request only (too long, rejected, busy, timed out, incomplete).
  request,

  /// DeepSeek is off for the rest of this app session: the balance is
  /// empty or the owner switched the function off. Alex: "do not retry in
  /// a loop".
  disabled,
}

class DeepseekException implements Exception {
  final DeepseekFailure failure;
  final String code;
  const DeepseekException(this.failure, this.code);

  @override
  String toString() => 'DeepseekException($code)';
}

/// Alex's callable function `deepseekChat` in forditva-151 (contract of
/// 2026-10-21, `API-deepseekChat-for-Abdulsalam-21oct.md`). The DeepSeek key
/// stays on the server; App Check proves the call comes from the app.
/// Thinking is always off and there is no JSON mode, so the Tutor checks its
/// JSON as it does for Gemini.
final HttpsCallable _deepseekChat = FirebaseFunctions.instanceFor(
  region: 'europe-west1',
).httpsCallable(
  'deepseekChat',
  // 70 s: the function gives up on DeepSeek after 55 s, plus up to 15 s of
  // cold start, so the function answers first with deadline-exceeded.
  options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
);

/// The function's limits: system + user at most 100,000 UTF-8 bytes, and
/// maxOutputTokens 1 to 3700 (an answer at the cap must end before the
/// 55 s upstream timeout).
const deepseekMaxRequestBytes = 100000;
const deepseekMaxOutputTokens = 3700;

/// Whether [request] fits the function's size limit. Longer texts go
/// straight to Gemini.
bool deepseekAccepts(TextAiRequest request) =>
    utf8.encode(request.system ?? '').length +
        utf8.encode(request.user).length <=
    deepseekMaxRequestBytes;

/// Sends [request] to `deepseekChat`. Throws [DeepseekException] on any
/// failure; the caller falls back to Gemini and charges nothing for it.
Future<TextAiResult> deepseekGenerate(
  AiModel model,
  TextAiRequest request,
) async {
  try {
    final watch = Stopwatch()..start();
    final result = await _deepseekChat.call<Map<String, dynamic>>({
      'model': model.id,
      'system': request.system ?? '',
      'user': request.user,
      'temperature': (request.temperature ?? 1.0).clamp(0.0, 2.0),
      'maxOutputTokens': (request.maxOutputTokens ?? deepseekMaxOutputTokens)
          .clamp(1, deepseekMaxOutputTokens),
    });
    final d = result.data;
    final r = TextAiResult(
      text: d['text'] as String,
      modelVersion: model.id,
      inputTokens: d['inputTokens'] as int,
      cachedInputTokens: d['cachedInputTokens'] as int,
      outputTokens: d['outputTokens'] as int,
    );
    debugPrint(
      'DeepSeek call: ${watch.elapsedMilliseconds} ms, '
      '${r.inputTokens} in (${r.cachedInputTokens} cached) / '
      '${r.outputTokens} out',
    );
    return r;
  } on FirebaseFunctionsException catch (e) {
    // Never log the texts, only the codes.
    final reason = (e.details is Map) ? (e.details as Map)['reason'] : null;
    debugPrint(
      'DeepSeek failed: ${e.code}${reason != null ? ' ($reason)' : ''}',
    );
    throw DeepseekException(
      e.code == 'permission-denied'
          ? DeepseekFailure.disabled
          : DeepseekFailure.request,
      reason != null ? '${e.code}/$reason' : e.code,
    );
  } catch (e) {
    // A reply without the expected fields, or a platform error.
    debugPrint('DeepSeek failed: ${e.runtimeType}');
    throw const DeepseekException(DeepseekFailure.request, 'client');
  }
}
