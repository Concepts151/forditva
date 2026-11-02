// FORDITVA Tutor + translation benchmark: Gemini vs DeepSeek.
//
// Implements Markus's DEVELOPER_HANDOFF_EN.md (2026-10-12): the 120 Tutor runs
// from input/run_manifest.json on input/test_sentences.json, plus a plain
// translation test on input/translation_texts.txt. Uses the app's production
// Tutor prompts (lib/tutor/tutor_core.dart, identical to the handoff files)
// and the app's standard translation prompt. Outside the app: no WIU, no
// Token Server, no change to the app's routing.
//
// Run from the repo root:   dart run tool/tutor_benchmark/tutor_benchmark.dart
// Options: --only tutor | translation   --cases T01,T02   --concurrency 6
//          --providers gemini,deepseek   --modes level_focus,decoder
//          --deepseek-json-mode (also send response_format json_object; off by
//          default like the app, since it cannot return a top-level array)
// Keys from .env.dev (not bundled into the app): GEMINI_API_KEY,
// DEEPSEEK_API_KEY.
// Output: build/tutor_benchmark/<timestamp>/ (see README.md).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:forditva/services/translation_prompts.dart';
import 'package:forditva/tutor/tutor_core.dart';
import 'package:http/http.dart' as http;

const inputDir = 'tool/tutor_benchmark/input';

// ---------------------------------------------------------------- settings

/// Pinned models and settings. Both Tutor setups are the low-creativity,
/// non-reasoning variant the handoff asks for (temperature 0.2 as in the
/// app; thinking off). Translation uses the app's settings (temperature 0).
class Setup {
  final String provider; // gemini | deepseek
  final String model;
  final double temperature;
  final bool json;
  final bool thinkingOff;
  const Setup(
    this.provider,
    this.model, {
    required this.temperature,
    required this.json,
    required this.thinkingOff,
  });

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'model': model,
    'temperature': temperature,
    'json_output': json,
    if (provider == 'deepseek' && json)
      'response_format_json_object': deepseekJsonMode,
    'thinking': thinkingOff ? 'off' : 'model default',
    if (provider == 'gemini' && thinkingOff && model.contains('flash-lite'))
      'note':
          'Flash-Lite rejects thinkingBudget 0 and does not think; '
          'setting left out',
  };
}

var tutorSetups = {
  'gemini': Setup(
    'gemini',
    'gemini-3.8-flash',
    temperature: 0.2,
    json: true,
    thinkingOff: true,
  ),
  'deepseek': Setup(
    'deepseek',
    'deepseek-flash',
    temperature: 0.2,
    json: true,
    thinkingOff: true,
  ),
};

/// DeepSeek gets no response_format by default, like the app: its JSON mode
/// cannot return a top-level array (19 of 40 Mode 1 answers came back as a
/// single object in the first run). --deepseek-json-mode turns it on.
var deepseekJsonMode = false;

const translationSetups = {
  'gemini': Setup(
    'gemini',
    'gemini-3.5-flash-lite',
    temperature: 0,
    json: false,
    thinkingOff: false,
  ),
  'deepseek': Setup(
    'deepseek',
    'deepseek-flash',
    temperature: 0,
    json: false,
    thinkingOff: true,
  ),
};

// ------------------------------------------------------------------ prices

/// Verified prices (USD per 1M tokens), checked 2026-10-12 on
/// ai.google.dev/gemini-api/docs/pricing and api-docs.deepseek.com.
/// Returns null when a billable category has no verified price.
double? usdFor(String model, Map<String, int?> u, DateTime utc) {
  final input = u['input'] ?? 0;
  final cached = u['cached'] ?? 0;
  final output = u['billable_output'] ?? 0;
  double inP, cacheP, outP;
  switch (model) {
    case 'gemini-3.8-flash':
      final y2027 = utc.isAfter(DateTime.utc(2026, 12, 31, 23, 59, 59));
      inP = y2027 ? 1.50 : 0.75;
      cacheP = y2027 ? 0.15 : 0.075;
      outP = y2027 ? 7.50 : 3.75;
    case 'gemini-3.5-flash-lite':
      inP = 0.30;
      cacheP = 0.03;
      outP = 2.50;
    case 'deepseek-flash':
      final peak = isDeepseekPeak(utc);
      inP = peak ? 0.30 : 0.15;
      cacheP = peak ? 0.006 : 0.003;
      outP = peak ? 1.20 : 0.60;
    default:
      return null;
  }
  return ((input - cached) * inP + cached * cacheP + output * outP) / 1e6;
}

/// DeepSeek peak: 01:00-04:00 and 06:00-10:00 UTC, Monday to Friday
/// (Chinese public holidays, which are off-peak, are not modelled).
bool isDeepseekPeak(DateTime utc) {
  if (utc.weekday > 5) return false;
  final h = utc.hour;
  return (h >= 1 && h < 4) || (h >= 6 && h < 10);
}

// ------------------------------------------------------------------- calls

String _env(String name) {
  for (final line in File('.env.dev').readAsLinesSync()) {
    if (!line.startsWith('$name=')) continue;
    var v = line.substring(name.length + 1).trim();
    if (v.length >= 2 && (v.startsWith('"') || v.startsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }
  throw StateError('$name missing in .env.dev');
}

final _client = http.Client();

/// One HTTP attempt with everything the handoff asks to keep.
class Attempt {
  final int number;
  final String timestamp;
  final int ms;
  final int? httpStatus;
  final String rawBody;
  final String text;
  final Map<String, dynamic>? rawUsage;
  final Map<String, int?> usage;
  final String? modelVersion;
  final double? usd;
  final String? error;
  // Filled in after parsing.
  Object? parsed;
  bool appAccepts = false;
  List<Map<String, dynamic>> checks = [];

  Attempt({
    required this.number,
    required this.timestamp,
    required this.ms,
    required this.httpStatus,
    required this.rawBody,
    required this.text,
    required this.rawUsage,
    required this.usage,
    required this.modelVersion,
    required this.usd,
    this.error,
  });

  bool get valid => checks.isNotEmpty && checks.every((c) => c['pass'] == true);

  Map<String, dynamic> toJson() => {
    'attempt': number,
    'timestamp': timestamp,
    'response_ms': ms,
    'http_status': httpStatus,
    'error': error,
    'model_version': modelVersion,
    'usage': usage,
    'usage_raw': rawUsage,
    'usd': usd,
    'text': text,
    'parsed_json': parsed,
    'accepted_by_app_parser': appAccepts,
    'validation': checks,
    'valid': valid,
    'raw_response': rawBody,
  };
}

Future<Attempt> call(Setup s, String system, String user, int number) async {
  final start = DateTime.now().toUtc();
  final watch = Stopwatch()..start();
  http.Response? res;
  String? error;
  try {
    if (s.provider == 'gemini') {
      res = await _client
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              '${s.model}:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _env('GEMINI_API_KEY'),
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': system},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': user},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': s.temperature,
                if (s.json) 'responseMimeType': 'application/json',
                if (s.json) 'maxOutputTokens': 32768,
                if (s.thinkingOff && !s.model.contains('flash-lite'))
                  'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(minutes: 4));
    } else {
      res = await _client
          .post(
            Uri.parse('https://api.deepseek.com/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_env('DEEPSEEK_API_KEY')}',
            },
            body: jsonEncode({
              'model': s.model,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
              'temperature': s.temperature,
              if (s.json && deepseekJsonMode)
                'response_format': {'type': 'json_object'},
              if (s.json) 'max_tokens': 32768,
              'thinking': {'type': s.thinkingOff ? 'disabled' : 'enabled'},
            }),
          )
          .timeout(const Duration(minutes: 4));
    }
  } catch (e) {
    error = e.toString();
  }
  final ms = watch.elapsedMilliseconds;
  final raw = res == null ? '' : utf8.decode(res.bodyBytes);
  Map<String, dynamic>? data;
  try {
    data = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {}
  if (res != null && res.statusCode != 200) {
    error ??= 'HTTP ${res.statusCode}';
  }

  var text = '';
  Map<String, dynamic>? rawUsage;
  final usage = <String, int?>{};
  String? version;
  if (data != null && s.provider == 'gemini') {
    final parts = data['candidates']?[0]?['content']?['parts'] as List?;
    text =
        [
          for (final p in parts ?? const [])
            if (p is Map && p['thought'] != true && p['text'] is String)
              p['text'],
        ].join();
    rawUsage = data['usageMetadata'] as Map<String, dynamic>?;
    final cand = rawUsage?['candidatesTokenCount'] as int?;
    final thoughts = rawUsage?['thoughtsTokenCount'] as int?;
    usage
      ..['input'] = rawUsage?['promptTokenCount'] as int?
      ..['cached'] = rawUsage?['cachedContentTokenCount'] as int?
      ..['output'] = cand
      ..['reasoning'] = thoughts
      ..['total_reported'] = rawUsage?['totalTokenCount'] as int?
      // Gemini reports thinking separately from candidates; both are
      // billed as output.
      ..['billable_output'] = (cand ?? 0) + (thoughts ?? 0);
    version = data['modelVersion'] as String?;
  } else if (data != null) {
    text = data['choices']?[0]?['message']?['content'] as String? ?? '';
    rawUsage = data['usage'] as Map<String, dynamic>?;
    final completion = rawUsage?['completion_tokens'] as int?;
    usage
      ..['input'] = rawUsage?['prompt_tokens'] as int?
      ..['cached'] = rawUsage?['prompt_cache_hit_tokens'] as int?
      ..['output'] = completion
      ..['reasoning'] =
          rawUsage?['completion_tokens_details']?['reasoning_tokens'] as int?
      ..['total_reported'] = rawUsage?['total_tokens'] as int?
      // DeepSeek's completion_tokens already include reasoning tokens.
      ..['billable_output'] = completion;
    version = [
      data['model'],
      if (data['system_fingerprint'] != null)
        'fingerprint ${data['system_fingerprint']}',
    ].join(', ');
  }
  return Attempt(
    number: number,
    timestamp: start.toIso8601String(),
    ms: ms,
    httpStatus: res?.statusCode,
    rawBody: raw,
    text: text,
    rawUsage: rawUsage,
    usage: usage,
    modelVersion: version,
    usd:
        error == null && usage['input'] != null
            ? usdFor(s.model, usage, start)
            : null,
    error: error,
  );
}

// -------------------------------------------------------------- validation

const _modeNames = {
  'level_focus': TutorMode.understanding,
  'decoder': TutorMode.decoding,
  'structured_analysis': TutorMode.focus,
};

const _itemKeys = ['term', 'explanation', 'example_hu', 'example_translation'];

/// The handoff's automatic checks (necessary, not sufficient).
List<Map<String, dynamic>> validate(
  Attempt a,
  String mode,
  int? level,
  String source,
) {
  final checks = <Map<String, dynamic>>[];
  void check(String name, bool pass, [String detail = '']) =>
      checks.add({'check': name, 'pass': pass, 'detail': detail});

  if (a.error != null) {
    check('request succeeded', false, a.error!);
    return checks;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(a.text.trim());
  } catch (e) {
    check('valid JSON', false, 'not parseable as JSON');
    return checks;
  }
  check('valid JSON', true);
  a.parsed = decoded;
  final isArray = decoded is List;
  check(
    'root is an array',
    isArray,
    isArray
        ? ''
        : 'root is ${decoded is Map ? 'a single object' : decoded.runtimeType}',
  );
  if (!isArray) return checks;
  final list = decoded;
  check('exactly one item', list.length == 1, '${list.length} items');
  if (list.isEmpty || list.first is! Map) return checks;
  final item = Map<String, dynamic>.from(list.first as Map);

  check(
    'source sentence unchanged',
    item['hu'] == source,
    item['hu'] == source ? '' : 'hu: ${item['hu']}',
  );

  bool goodItems(dynamic items, {int? min, int? max}) {
    if (items is! List) return false;
    if (min != null && items.length < min) return false;
    if (max != null && items.length > max) return false;
    return items.every(
      (i) =>
          i is Map &&
          _itemKeys.every(
            (k) => i[k] is String && (i[k] as String).trim().isNotEmpty,
          ),
    );
  }

  switch (mode) {
    case 'level_focus':
      final l = item['level'];
      final lv = l is int ? l : int.tryParse('$l');
      check('level matches', lv == level, 'returned $l, expected $level');
      check(
        'intro present',
        item['intro'] is String && (item['intro'] as String).isNotEmpty,
      );
      final n = item['items'] is List ? (item['items'] as List).length : 0;
      check(
        '1-3 complete items',
        goodItems(item['items'], min: 1, max: 3),
        '$n items',
      );
    case 'decoder':
      final keys = item.keys.toSet();
      check(
        'exactly hu, direct, correct',
        keys.length == 3 && keys.containsAll(['hu', 'direct', 'correct']),
        keys.join(', '),
      );
      check(
        'direct and correct non-empty',
        '${item['direct'] ?? ''}'.isNotEmpty &&
            '${item['correct'] ?? ''}'.isNotEmpty,
      );
    case 'structured_analysis':
      final n = item['items'] is List ? (item['items'] as List).length : 0;
      check(
        'complete items (any number)',
        goodItems(item['items'], min: 1),
        '$n items',
      );
  }
  return checks;
}

// -------------------------------------------------------------------- runs

class Case {
  final String id, focus, hu, referenceDe, reviewPoints;
  Case(Map<String, dynamic> j)
    : id = j['id'],
      focus = j['focus'] ?? '',
      hu = j['hu'],
      referenceDe = j['reference_de'] ?? '',
      reviewPoints = j['review_points'] ?? '';
}

class TutorRun {
  final Map<String, dynamic> spec;
  final Case kase;
  final Setup setup;
  final List<Attempt> attempts = [];
  TutorRun(this.spec, this.kase, this.setup);

  String get id => spec['run_id'];
  String get mode => spec['mode'];
  int? get level => spec['level'];
  String get provider => spec['provider'];
  Attempt get last => attempts.last;

  int sum(String k) => attempts.fold(0, (a, t) => a + (t.usage[k] ?? 0));
  int get ms => attempts.fold(0, (a, t) => a + t.ms);
  double? get usd =>
      attempts.any((t) => t.usd == null)
          ? null
          : attempts.fold<double>(0, (a, t) => a + t.usd!);

  Map<String, dynamic> toJson() => {
    'run_id': id,
    'case_id': kase.id,
    'source_sentence': kase.hu,
    'mode': mode,
    'level': level,
    'output_language': spec['target_language'],
    'settings': setup.toJson(),
    'final_valid': last.valid,
    'retried': attempts.length > 1,
    'totals': {
      'input': sum('input'),
      'cached': sum('cached'),
      'output': sum('output'),
      'reasoning': sum('reasoning'),
      'billable_output': sum('billable_output'),
      'response_ms': ms,
      'usd': usd,
    },
    'attempts': [for (final a in attempts) a.toJson()],
  };
}

Future<void> runTutor(TutorRun r) async {
  final mode = _modeNames[r.mode]!;
  final system = tutorSystemPrompt(mode, 'DE', r.level ?? 0);
  // Same as the app: one retry with the handoffs' retry instruction when
  // the app's own parser and checks reject the reply.
  for (var n = 1; n <= 2; n++) {
    final user = n == 1 ? r.kase.hu : '${r.kase.hu}\n\n$tutorRetryInstruction';
    final a = await call(r.setup, system, user, n);
    a.checks = validate(a, r.mode, r.level, r.kase.hu);
    final appParsed = parseTutorArray(a.text);
    a.appAccepts = appParsed != null && tutorValidator(mode)(appParsed);
    r.attempts.add(a);
    stdout.writeln(
      '${a.valid ? 'ok ' : 'BAD'} ${(a.ms / 1000).toStringAsFixed(1)}s '
      '${r.id}${n > 1 ? ' (retry)' : ''}',
    );
    if (a.appAccepts || a.error != null) break;
  }
}

class TranslationRun {
  final String id, from, to, source, reference;
  final Setup setup;
  late Attempt attempt;
  TranslationRun(
    this.id,
    this.from,
    this.to,
    this.source,
    this.reference,
    this.setup,
  );

  Map<String, dynamic> toJson() => {
    'run_id': id,
    'direction': '$from>$to',
    'source': source,
    'reference': reference,
    'settings': setup.toJson(),
    'attempt': attempt.toJson(),
  };
}

/// Splits the translation file into its three sections (Hungarian original,
/// English and German reference), separated by ### lines.
Map<String, String> readTranslationTexts() {
  final raw = File('$inputDir/translation_texts.txt').readAsStringSync();
  final out = <String, String>{};
  for (final block in raw.split(RegExp(r'^###\s*$', multiLine: true))) {
    final lines = block.trim().split('\n');
    final title = lines.first.toLowerCase();
    final body = lines.skip(1).join('\n').trim();
    if (title.startsWith('hungarian')) out['HU'] = body;
    if (title.startsWith('engl')) out['EN'] = body;
    if (title.startsWith('german')) out['DE'] = body;
  }
  return out;
}

Future<void> pool(List<Future<void> Function()> jobs, int width) async {
  var next = 0;
  Future<void> worker() async {
    while (next < jobs.length) {
      await jobs[next++]();
    }
  }

  await Future.wait(List.generate(width, (_) => worker()));
}

// -------------------------------------------------------------------- main

Future<void> main(List<String> args) async {
  String? only;
  Set<String>? cases, providers, modes;
  var width = 6;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--only':
        only = args[++i];
      case '--cases':
        cases = args[++i].split(',').toSet();
      case '--concurrency':
        width = int.parse(args[++i]);
      case '--providers':
        providers = args[++i].split(',').toSet();
      case '--modes':
        modes = args[++i].split(',').toSet();
      case '--deepseek-json-mode':
        deepseekJsonMode = true;
    }
  }

  final sentences =
      jsonDecode(File('$inputDir/test_sentences.json').readAsStringSync())
          as Map<String, dynamic>;
  final caseById = {
    for (final c in sentences['cases'] as List) c['id'] as String: Case(c),
  };
  final manifest =
      jsonDecode(File('$inputDir/run_manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  final tutorRuns = <TutorRun>[
    if (only != 'translation')
      for (final spec in manifest['runs'] as List)
        if ((cases == null || cases.contains(spec['case_id'])) &&
            (providers == null || providers.contains(spec['provider'])) &&
            (modes == null || modes.contains(spec['mode'])))
          TutorRun(
            Map<String, dynamic>.from(spec),
            caseById[spec['case_id']]!,
            tutorSetups[spec['provider']]!,
          ),
  ];

  final texts = readTranslationTexts();
  final translationRuns = <TranslationRun>[
    if (only != 'tutor')
      for (final (from, to, refKey) in [
        ('HU', 'DE', 'DE'),
        ('HU', 'EN', 'EN'),
        ('DE', 'HU', 'HU'),
        ('EN', 'HU', 'HU'),
      ])
        for (final p in ['gemini', 'deepseek'])
          if (providers == null || providers.contains(p))
            TranslationRun(
              'TR-$from-$to-$p',
              from,
              to,
              texts[from]!,
              texts[refKey]!,
              translationSetups[p]!,
            ),
  ];

  stdout.writeln(
    '${tutorRuns.length} Tutor runs, ${translationRuns.length} translation '
    'runs, concurrency $width',
  );
  await pool([
    for (final r in tutorRuns) () => runTutor(r),
    for (final t in translationRuns)
      () async {
        t.attempt = await call(
          t.setup,
          translationSystemPrompt(t.from, t.to),
          translationUserMessage(t.source),
          1,
        );
        stdout.writeln(
          '${t.attempt.error == null ? 'ok ' : 'BAD'} '
          '${(t.attempt.ms / 1000).toStringAsFixed(1)}s ${t.id}',
        );
      },
  ], width);
  _client.close();

  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[:.]'),
    '-',
  );
  final dir = Directory('build/tutor_benchmark/$stamp')
    ..createSync(recursive: true);
  final enc = const JsonEncoder.withIndent('  ');
  File('${dir.path}/results.json').writeAsStringSync(
    enc.convert({
      'generated_utc': DateTime.now().toUtc().toIso8601String(),
      'tutor_settings': {
        for (final e in tutorSetups.entries) e.key: e.value.toJson(),
      },
      'translation_settings': {
        for (final e in translationSetups.entries) e.key: e.value.toJson(),
      },
      'tutor_runs': [for (final r in tutorRuns) r.toJson()],
      'translation_runs': [for (final t in translationRuns) t.toJson()],
    }),
  );

  // Blind labels: per comparable pair, a coin flip decides which model is
  // "A". Fixed seed so a rerun of the report keeps the same labels.
  final rng = Random(20261012);
  final blind = <String, Map<String, String>>{};
  String pairKey(TutorRun r) => '${r.kase.id}|${r.mode}|${r.level}';
  for (final k in tutorRuns.map(pairKey).toSet()) {
    final flip = rng.nextBool();
    blind[k] = {
      'A': flip ? 'deepseek' : 'gemini',
      'B': flip ? 'gemini' : 'deepseek',
    };
  }
  for (final t in translationRuns.map((t) => '${t.from}>${t.to}').toSet()) {
    final flip = rng.nextBool();
    blind[t] = {
      'A': flip ? 'deepseek' : 'gemini',
      'B': flip ? 'gemini' : 'deepseek',
    };
  }
  File('${dir.path}/blind_key.json').writeAsStringSync(enc.convert(blind));

  final summary = summaryRows(tutorRuns, translationRuns);
  File('${dir.path}/summary.csv').writeAsStringSync(
    [
      summary.first.join(','),
      for (final row in summary.skip(1)) row.map(_csv).join(','),
    ].join('\n'),
  );
  File(
    '${dir.path}/scores.csv',
  ).writeAsStringSync(scoreSheet(tutorRuns, translationRuns, blind));
  for (final named in [true, false]) {
    File(
      '${dir.path}/${named ? 'report.html' : 'report_blind.html'}',
    ).writeAsStringSync(
      htmlReport(
        tutorRuns,
        translationRuns,
        caseById,
        blind,
        summary,
        named: named,
      ),
    );
  }
  stdout.writeln('Done: ${dir.path}');
}

String _csv(Object? v) {
  final s = '${v ?? ''}';
  return s.contains(',') || s.contains('"')
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

// ----------------------------------------------------------------- summary

List<List<Object?>> summaryRows(
  List<TutorRun> tutor,
  List<TranslationRun> translation,
) {
  final rows = <List<Object?>>[
    [
      'task',
      'mode',
      'level',
      'provider',
      'model',
      'runs',
      'valid_first_attempt',
      'valid_final',
      'retries',
      'avg_ms',
      'avg_input',
      'avg_cached',
      'avg_output',
      'avg_reasoning',
      'total_usd',
      'usd_per_1000',
    ],
  ];
  final groups = <String, List<TutorRun>>{};
  for (final r in tutor) {
    groups.putIfAbsent('${r.mode}|${r.level}|${r.provider}', () => []).add(r);
  }
  for (final g in groups.values) {
    final f = g.first;
    double avg(num Function(TutorRun) v) =>
        g.map(v).fold<double>(0, (a, b) => a + b) / g.length;
    final usds = g.map((r) => r.usd);
    final total =
        usds.any((u) => u == null)
            ? null
            : usds.fold<double>(0, (a, b) => a + b!);
    rows.add([
      'tutor',
      f.mode,
      f.level,
      f.provider,
      f.setup.model,
      g.length,
      g.where((r) => r.attempts.first.valid).length,
      g.where((r) => r.last.valid).length,
      g.where((r) => r.attempts.length > 1).length,
      avg((r) => r.ms).round(),
      avg((r) => r.sum('input')).round(),
      avg((r) => r.sum('cached')).round(),
      avg((r) => r.sum('output')).round(),
      avg((r) => r.sum('reasoning')).round(),
      total?.toStringAsFixed(5),
      total == null ? null : (total / g.length * 1000).toStringAsFixed(2),
    ]);
  }
  for (final t in translation) {
    final a = t.attempt;
    rows.add([
      'translation',
      '${t.from}>${t.to}',
      null,
      t.setup.provider,
      t.setup.model,
      1,
      a.error == null ? 1 : 0,
      a.error == null ? 1 : 0,
      0,
      a.ms,
      a.usage['input'],
      a.usage['cached'],
      a.usage['output'],
      a.usage['reasoning'],
      a.usd?.toStringAsFixed(5),
      a.usd == null ? null : (a.usd! * 1000).toStringAsFixed(2),
    ]);
  }
  return rows;
}

String scoreSheet(
  List<TutorRun> tutor,
  List<TranslationRun> translation,
  Map<String, Map<String, String>> blind,
) {
  final b = StringBuffer(
    'item,side,grammatical_accuracy_1_5,learner_usefulness_1_5,'
    'natural_german_1_5,mode_compliance_1_5,notes\n',
  );
  final seen = <String>{};
  for (final r in tutor) {
    final k = '${r.kase.id}|${r.mode}|${r.level}';
    if (!seen.add(k)) continue;
    final label =
        '${r.kase.id} ${r.mode}${r.level == null ? '' : ' L${r.level}'}';
    b.writeln('$label,A,,,,,');
    b.writeln('$label,B,,,,,');
  }
  for (final k in translation.map((t) => '${t.from}>${t.to}').toSet()) {
    b.writeln('translation $k,A,,,,,');
    b.writeln('translation $k,B,,,,,');
  }
  return b.toString();
}

// -------------------------------------------------------------------- html

String esc(Object? s) => const HtmlEscape().convert('${s ?? ''}');

String _usageLine(Attempt a) {
  final u = a.usage;
  final parts = [
    '${a.ms} ms',
    'in ${u['input'] ?? 'n/a'}',
    'cached ${u['cached'] ?? 'n/a'}',
    'out ${u['output'] ?? 'n/a'}',
    'reasoning ${u['reasoning'] ?? 'n/a'}',
    'total ${u['total_reported'] ?? 'n/a'}',
    a.usd == null ? 'USD n/a' : '\$${a.usd!.toStringAsFixed(5)}',
  ];
  return parts.join(' · ');
}

String _renderTutor(Object? parsed, String mode) {
  if (parsed is! List || parsed.isEmpty || parsed.first is! Map) {
    return '<p class="bad">No usable JSON.</p>';
  }
  final b = StringBuffer();
  for (final s in parsed) {
    final m = s as Map;
    if (m['level'] != null) {
      b.write('<p class="meta">level: ${esc(m['level'])}</p>');
    }
    if (m['intro'] != null) b.write('<p><i>${esc(m['intro'])}</i></p>');
    if (mode == 'decoder') {
      b.write(
        '<p><b>direct</b></p><pre class="direct">${esc(m['direct'])}</pre>'
        '<p><b>correct</b><br>${esc(m['correct'])}</p>',
      );
    }
    final items = m['items'];
    if (items is List) {
      b.write('<ol>');
      for (final i in items) {
        if (i is! Map) continue;
        b.write(
          '<li><b>${esc(i['term'])}</b>: ${esc(i['explanation'])}'
          '<div class="ex">${esc(i['example_hu'])}<br>'
          '= ${esc(i['example_translation'])}</div></li>',
        );
      }
      b.write('</ol>');
    }
  }
  return b.toString();
}

String _attemptBlock(Attempt a, String mode, {required bool tutor}) {
  final b = StringBuffer();
  final failed = a.checks.where((c) => c['pass'] != true).toList();
  b.write(
    '<p class="meta">${esc(_usageLine(a))}<br>'
    'model: ${esc(a.modelVersion ?? 'n/a')}</p>',
  );
  if (tutor) {
    b.write(
      failed.isEmpty
          ? '<p class="good">All automatic checks passed.</p>'
          : '<p class="bad">Failed: ${esc(failed.map((c) => '${c['check']}'
          '${'${c['detail']}'.isEmpty ? '' : ' (${c['detail']})'}').join('; '))}</p>',
    );
    b.write(_renderTutor(a.parsed, mode));
  } else {
    b.write(
      a.error != null
          ? '<p class="bad">${esc(a.error)}</p>'
          : '<div class="tr">${esc(a.text).replaceAll('\n', '<br>')}</div>',
    );
  }
  b.write(
    '<details><summary>Raw model text</summary><pre>${esc(a.text)}</pre>'
    '</details><details><summary>Raw provider response</summary>'
    '<pre>${esc(a.rawBody)}</pre></details>',
  );
  return b.toString();
}

String _side(TutorRun? r, String label) {
  if (r == null) return '<td><p class="bad">missing</p></td>';
  final b = StringBuffer('<td><h4>${esc(label)}</h4>');
  if (r.attempts.length > 1) {
    b.write(
      '<p class="bad">First attempt was rejected and retried. '
      'First attempt:</p><div class="first">',
    );
    b.write(_attemptBlock(r.attempts.first, r.mode, tutor: true));
    b.write('</div><p><b>Retry (final):</b></p>');
  }
  b.write(_attemptBlock(r.last, r.mode, tutor: true));
  return '$b</td>';
}

String htmlReport(
  List<TutorRun> tutor,
  List<TranslationRun> translation,
  Map<String, Case> cases,
  Map<String, Map<String, String>> blind,
  List<List<Object?>> summary, {
  required bool named,
}) {
  String label(String key, String side) {
    final p = blind[key]![side]!;
    return named
        ? (p == 'gemini'
            ? 'Gemini (${tutorSetups['gemini']!.model})'
            : 'DeepSeek (${tutorSetups['deepseek']!.model})')
        : 'Model $side';
  }

  final b = StringBuffer('''<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Forditva Tutor benchmark${named ? '' : ' (blind)'}</title>
<style>
body{font:15px/1.45 -apple-system,Segoe UI,Roboto,sans-serif;margin:16px;color:#222;background:#fff}
h1{font-size:22px}h2{margin-top:36px;border-bottom:2px solid #436F4D;padding-bottom:4px}
h3{margin-top:22px;color:#436F4D}h4{margin:0 0 6px}
table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:8px;vertical-align:top}
table.pair td{width:50%}th{background:#f3f3f3;text-align:left}
.meta{color:#666;font-size:12px}.good{color:#2e7d32}.bad{color:#c62828}
.ex{color:#555;font-style:italic;margin:2px 0 6px}pre{white-space:pre-wrap;font-size:12px;background:#f7f7f7;padding:6px}
pre.direct{font-size:15px;background:#fff8e1}.first{opacity:.75;border-left:3px solid #c62828;padding-left:8px}
.src{font-size:17px;background:#eef5ef;padding:8px}.tr{white-space:normal}
.summary td,.summary th{font-size:12px;padding:4px}
</style></head><body>
<h1>Forditva Tutor benchmark: Gemini vs DeepSeek${named ? '' : ' (blind)'}</h1>
''');
  b.write(
    named
        ? '<p>Settings: Tutor Gemini <code>${tutorSetups['gemini']!.model}</code> and DeepSeek <code>${tutorSetups['deepseek']!.model}</code>, both temperature 0.2 and thinking off; Gemini with JSON output mode, DeepSeek asked for JSON by the prompt only (its JSON mode cannot return the required top-level array). Translation Gemini <code>${translationSetups['gemini']!.model}</code> and DeepSeek <code>${translationSetups['deepseek']!.model}</code>, temperature 0. Prompts: the app\'s production prompts, explanation language German. Costs use verified provider prices; DeepSeek priced by the time of each request (peak or off-peak).</p>'
        : '<p>Model names are hidden: A and B are assigned at random per comparison. The key is in <code>blind_key.json</code> and the named version in <code>report.html</code>. Score sheet: <code>scores.csv</code>.</p>',
  );

  if (named) {
    b.write(
      '<h2>Summary</h2><p class="meta">Times are end-to-end per run; tokens '
      'are averages per run; total_usd is for all runs in the row. DeepSeek '
      'prices depend on the time of day (off-peak is half of peak), see '
      'the timestamps in results.json.</p>'
      '<div style="overflow-x:auto"><table class="summary"><tr>',
    );
    for (final h in summary.first) {
      b.write('<th>${esc(h)}</th>');
    }
    b.write('</tr>');
    for (final row in summary.skip(1)) {
      b.write('<tr>${row.map((v) => '<td>${esc(v)}</td>').join()}</tr>');
    }
    b.write('</table></div>');
  }

  for (final c in cases.values) {
    final runs = tutor.where((r) => r.kase.id == c.id).toList();
    if (runs.isEmpty) continue;
    b.write(
      '<h2>${esc(c.id)}: ${esc(c.focus)}</h2>'
      '<p class="src">${esc(c.hu)}</p>'
      '<p class="meta">Reference (for review only, not sent to the models): '
      '${esc(c.referenceDe)}<br>Review points: ${esc(c.reviewPoints)}</p>',
    );
    for (final (mode, title) in [
      ('level_focus', 'Mode 1, level-dependent selective explanation'),
      ('decoder', 'Mode 2, Decoder'),
      ('structured_analysis', 'Mode 3, full structured explanation'),
    ]) {
      final levels =
          runs
              .where((r) => r.mode == mode)
              .map((r) => r.level)
              .toSet()
              .toList();
      for (final lv in levels) {
        final key = '${c.id}|$mode|$lv';
        TutorRun? pick(String side) {
          final p = blind[key]![side];
          return runs
              .where((r) => r.mode == mode && r.level == lv && r.provider == p)
              .firstOrNull;
        }

        b.write(
          '<h3>$title${lv == null ? '' : ', level ${lv.toString().padLeft(2, '0')}'}</h3>'
          '<table class="pair"><tr>${_side(pick('A'), label(key, 'A'))}'
          '${_side(pick('B'), label(key, 'B'))}</tr></table>',
        );
      }
    }
  }

  if (translation.isNotEmpty) {
    b.write('<h2>Plain translation</h2>');
    for (final dir in translation.map((t) => '${t.from}>${t.to}').toSet()) {
      final ts = translation.where((t) => '${t.from}>${t.to}' == dir).toList();
      final f = ts.first;
      TranslationRun? pick(String side) =>
          ts.where((t) => t.setup.provider == blind[dir]![side]).firstOrNull;
      String cell(String side) {
        final t = pick(side);
        if (t == null) return '<td>missing</td>';
        final p = blind[dir]![side]!;
        final name =
            named
                ? '${p == 'gemini' ? 'Gemini' : 'DeepSeek'} (${t.setup.model})'
                : 'Model $side';
        return '<td><h4>${esc(name)}</h4>'
            '${_attemptBlock(t.attempt, '', tutor: false)}</td>';
      }

      b.write(
        '<h3>${esc(dir.replaceAll('>', ' → '))}</h3>'
        '<details><summary>Source text</summary><p>${esc(f.source)}</p></details>'
        '<details><summary>Reference translation (not sent to the models)</summary>'
        '<p>${esc(f.reference)}</p></details>'
        '<table class="pair"><tr>${cell('A')}${cell('B')}</tr></table>',
      );
    }
  }
  b.write('</body></html>');
  return b.toString();
}
