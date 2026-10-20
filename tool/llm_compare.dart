// Compares models on the Tutor and on plain translation, using the app's own
// prompts, JSON checks and price table (Markus, 2026-10-12: test DeepSeek
// against Gemini on 10 examples before changing anything).
//
// Run from the repo root:
//   dart run tool/llm_compare.dart [examples.txt] [--lang DE] [--level 27]
//
// examples.txt: one Hungarian text per line (blank lines and lines starting
// with # are ignored). Without a file, tool/llm_compare_examples.txt is used.
// Keys are read from .env.dev (GEMINI_API_KEY, DEEPSEEK_API_KEY), which is
// not bundled into the app.
// Writes build/llm_compare/report.md and raw.json.

import 'dart:convert';
import 'dart:io';

import 'package:forditva/services/ai/ai_models.dart';
import 'package:forditva/services/ai/text_ai.dart';
import 'package:forditva/services/translation_prompts.dart';
import 'package:forditva/tutor/tutor_core.dart';
import 'package:http/http.dart' as http;

/// One model setup under test.
class Contender {
  final String label;
  final AiModel model;
  final bool thinking;
  const Contender(this.label, this.model, {required this.thinking});
}

const tutorContenders = [
  Contender(
    'Gemini 3.8 Flash, accurate (app today)',
    AiModels.geminiFlash,
    thinking: true,
  ),
  Contender(
    'Gemini 3.8 Flash, fast ("Answer now")',
    AiModels.geminiFlash,
    thinking: false,
  ),
  Contender(
    'DeepSeek V4.1 Flash, no thinking',
    AiModels.deepseekFlash,
    thinking: false,
  ),
  Contender('Gemini 3.5 Flash-Lite', AiModels.geminiFlashLite, thinking: false),
];

const translationContenders = [
  Contender(
    'Gemini 3.5 Flash-Lite (app today)',
    AiModels.geminiFlashLite,
    thinking: true,
  ),
  Contender(
    'DeepSeek V4.1 Flash, no thinking',
    AiModels.deepseekFlash,
    thinking: false,
  ),
];

/// Real price (no margin) for the report, so it compares with Google's and
/// DeepSeek's price lists. Gemini Flash is priced as 3.8 Flash, the model
/// Google actually serves today, not the app's billing constants.
double realUsd(AiModel model, TextAiResult r) {
  final (inP, cachedP, outP) = switch (model.id) {
    'gemini-flash-latest' => (0.75, 0.75, 3.75),
    _ => (model.inputPerM, model.cachedInputPerM, model.outputPerM),
  };
  return ((r.inputTokens - r.cachedInputTokens) * inP +
          r.cachedInputTokens * cachedP +
          r.outputTokens * outP) /
      1e6;
}

class Run {
  final String task;
  final String example;
  final String contender;
  bool valid = false;
  int attempts = 0;
  double seconds = 0;
  int inputTokens = 0;
  int cachedTokens = 0;
  int outputTokens = 0;
  double usd = 0;
  String modelVersion = '';
  String reply = '';
  String? error;
  Run(this.task, this.example, this.contender);

  Map<String, dynamic> toJson() => {
    'task': task,
    'example': example,
    'contender': contender,
    'valid': valid,
    'attempts': attempts,
    'seconds': seconds,
    'inputTokens': inputTokens,
    'cachedTokens': cachedTokens,
    'outputTokens': outputTokens,
    'usd': usd,
    'modelVersion': modelVersion,
    'reply': reply,
    'error': error,
  };
}

Map<String, String> readEnv() {
  final env = <String, String>{};
  for (final line in File('.env.dev').readAsLinesSync()) {
    final i = line.indexOf('=');
    if (i <= 0 || line.trimLeft().startsWith('#')) continue;
    var v = line.substring(i + 1).trim();
    if (v.length >= 2 && (v.startsWith('"') || v.startsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    env[line.substring(0, i).trim()] = v;
  }
  return env;
}

late final Map<String, String> env;
final client = http.Client();

String keyFor(AiProvider p) => switch (p) {
  AiProvider.gemini => env['GEMINI_API_KEY'] ?? '',
  AiProvider.deepseek => env['DEEPSEEK_API_KEY'] ?? '',
};

/// Sends one request like the app does: JSON check, one retry with the
/// handoffs' retry instruction. Token counts and time cover both attempts.
Future<Run> runOne({
  required String task,
  required String example,
  // What is sent, when it differs from [example] (the translation tags).
  String? user,
  required Contender c,
  required String? system,
  required bool json,
  required double temperature,
  bool Function(List<Map<String, dynamic>>)? validate,
}) async {
  final run = Run(task, example, c.label);
  final watch = Stopwatch()..start();
  try {
    for (var attempt = 1; attempt <= (validate == null ? 1 : 2); attempt++) {
      run.attempts = attempt;
      final r = await generateText(
        c.model,
        TextAiRequest(
          system: system,
          user:
              attempt == 1
                  ? user ?? example
                  : '${user ?? example}\n\n$tutorRetryInstruction',
          json: json,
          temperature: temperature,
          thinking: c.thinking,
          maxOutputTokens: json ? 32768 : null,
        ),
        apiKey: keyFor(c.model.provider),
        client: client,
      ).timeout(const Duration(minutes: 4));
      run.inputTokens += r.inputTokens;
      run.cachedTokens += r.cachedInputTokens;
      run.outputTokens += r.outputTokens;
      run.usd += realUsd(c.model, r);
      run.modelVersion = r.modelVersion;
      run.reply = r.text;
      if (validate == null) {
        run.valid = r.text.trim().isNotEmpty;
        break;
      }
      final parsed = parseTutorArray(r.text);
      if (parsed != null && validate(parsed)) {
        run.valid = true;
        run.reply = const JsonEncoder.withIndent('  ').convert(parsed);
        break;
      }
    }
  } catch (e) {
    run.error = e.toString();
  }
  run.seconds = watch.elapsedMilliseconds / 1000;
  stdout.writeln(
    '${run.valid ? 'ok ' : 'BAD'} ${run.seconds.toStringAsFixed(1)}s '
    '$task | ${c.label} | ${_short(example)}',
  );
  return run;
}

String _short(String s) => s.length > 40 ? '${s.substring(0, 40)}...' : s;

/// Runs [jobs] with at most [width] in flight.
Future<List<Run>> pool(List<Future<Run> Function()> jobs, int width) async {
  final results = List<Run?>.filled(jobs.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < jobs.length) {
      final i = next++;
      results[i] = await jobs[i]();
    }
  }

  await Future.wait(List.generate(width, (_) => worker()));
  return results.cast<Run>();
}

Future<void> main(List<String> args) async {
  env = readEnv();
  var lang = 'DE';
  var level = 27;
  String? file;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--lang') {
      lang = args[++i];
    } else if (args[i] == '--level') {
      level = int.parse(args[++i]);
    } else {
      file = args[i];
    }
  }
  final examples =
      File(file ?? 'tool/llm_compare_examples.txt')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();

  final jobs = <Future<Run> Function()>[];
  for (final ex in examples) {
    for (final mode in TutorMode.values) {
      for (final c in tutorContenders) {
        jobs.add(
          () => runOne(
            task: 'tutor:${mode.name}',
            example: ex,
            c: c,
            system: tutorSystemPrompt(mode, lang, level),
            json: true,
            temperature: 0.2,
            validate: tutorValidator(mode),
          ),
        );
      }
    }
    // The examples are Hungarian: translate them into the explanation
    // language, as the Conversation page would.
    for (final c in translationContenders) {
      jobs.add(
        () => runOne(
          task: 'translate:HU>$lang',
          example: ex,
          user: translationUserMessage(ex),
          c: c,
          system: translationSystemPrompt('HU', lang),
          json: false,
          temperature: 0,
        ),
      );
    }
  }

  stdout.writeln('${examples.length} examples, ${jobs.length} requests');
  final runs = await pool(jobs, 6);
  client.close();

  final out = Directory('build/llm_compare')..createSync(recursive: true);
  File('${out.path}/raw.json').writeAsStringSync(
    const JsonEncoder.withIndent(
      '  ',
    ).convert([for (final r in runs) r.toJson()]),
  );
  File(
    '${out.path}/report.md',
  ).writeAsStringSync(report(runs, examples, lang, level));
  stdout.writeln('Report: ${out.path}/report.md');
}

String report(List<Run> runs, List<String> examples, String lang, int level) {
  final b = StringBuffer();
  b.writeln('# Tutor and translation: Gemini vs DeepSeek\n');
  b.writeln(
    'Explanation language $lang, level $level. Each example ran through the '
    "app's own prompts and JSON checks (one retry, like the app). Cost is "
    "the provider's real price without the 30 % margin; Gemini Flash is "
    'priced as 3.8 Flash, the model Google serves today.\n',
  );

  final tasks = runs.map((r) => r.task).toSet().toList();
  final contenders = runs.map((r) => r.contender).toSet().toList();

  b.writeln('## Summary\n');
  b.writeln(
    '| Task | Model | Valid | Avg time (s) | Avg tokens in / out | '
    'Avg cost (USD) | Cost per 1,000 |',
  );
  b.writeln('|---|---|---|---|---|---|---|');
  for (final t in tasks) {
    for (final c in contenders) {
      final rs = runs.where((r) => r.task == t && r.contender == c).toList();
      if (rs.isEmpty) continue;
      double avg(num Function(Run) f) =>
          rs.map(f).fold<double>(0, (a, v) => a + v) / rs.length;
      final usd = avg((r) => r.usd);
      b.writeln(
        '| $t | $c | ${rs.where((r) => r.valid).length}/${rs.length} | '
        '${avg((r) => r.seconds).toStringAsFixed(1)} | '
        '${avg((r) => r.inputTokens).round()} / '
        '${avg((r) => r.outputTokens).round()} | '
        '${usd.toStringAsFixed(5)} | ${(usd * 1000).toStringAsFixed(2)} |',
      );
    }
  }

  for (var i = 0; i < examples.length; i++) {
    final ex = examples[i];
    b.writeln('\n## Example ${i + 1}\n');
    b.writeln('> $ex\n');
    for (final t in tasks) {
      b.writeln('### $t\n');
      for (final r in runs.where((r) => r.example == ex && r.task == t)) {
        b.writeln('#### ${r.contender}\n');
        b.writeln(
          '${r.valid ? 'Valid' : '**Not valid**'}, '
          '${r.seconds.toStringAsFixed(1)} s, '
          '${r.inputTokens} in (${r.cachedTokens} cached) / '
          '${r.outputTokens} out, \$${r.usd.toStringAsFixed(5)}, '
          'model ${r.modelVersion}'
          '${r.attempts > 1 ? ', needed the retry' : ''}\n',
        );
        if (r.error != null) {
          b.writeln('Error: `${_short(r.error!)}`\n');
        } else if (t.startsWith('tutor') && r.valid) {
          b.writeln(_render(jsonDecode(r.reply) as List));
        } else {
          b.writeln('${r.reply.trim()}\n');
        }
      }
    }
  }
  return b.toString();
}

/// Readable text of a Tutor reply: every field of every sentence, items as
/// a list.
String _render(List sentences) {
  final b = StringBuffer();
  for (final s in sentences) {
    final m = s as Map;
    for (final e in m.entries) {
      if (e.value is List) {
        for (final item in e.value as List) {
          final it = item as Map;
          b.writeln(
            '- **${it['term']}**: ${it['explanation']}  \n'
            '  *${it['example_hu']}* = ${it['example_translation']}',
          );
        }
      } else {
        b.writeln('**${e.key}:** ${e.value}  ');
      }
    }
    b.writeln();
  }
  return b.toString();
}
