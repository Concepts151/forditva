import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../services/learning_store.dart';
import '../services/level_pref.dart';
import '../widgets/wiu_gate.dart';
import 'sentence_selection.dart';
import 'tutor_service.dart';

const Color _navRed = Color(0xFFCD2A3E);
const Color _navGreen = Color(0xFF436F4D);
const Color _selectedFill = Color(0xFFE9F3EB);

/// What the Tutor page should explain next.
class TutorRequest {
  final String text;

  /// The non-Hungarian language of the page the Tutor was opened from, used
  /// as the explanation language when the UI is Hungarian.
  final String? otherLangCode;

  /// Results saved in the Tutor history (re-opened entry), keyed like
  /// [_TutorPageState._key]; skips the sentence picker.
  final Map<String, dynamic>? cached;
  final String? cachedLang;

  const TutorRequest(
    this.text, {
    this.otherLangCode,
    this.cached,
    this.cachedLang,
  });
}

/// Opens the Tutor page from anywhere: the shell (main.dart) listens to
/// [request] and switches to the Tutor page.
class TutorLauncher {
  static final ValueNotifier<TutorRequest?> request = ValueNotifier(null);

  static void open(
    String text, {
    String? otherLangCode,
    Map<String, dynamic>? cached,
    String? cachedLang,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    request.value = TutorRequest(
      trimmed,
      otherLangCode: otherLangCode,
      cached: cached,
      cachedLang: cachedLang,
    );
  }
}

/// Tutor history entries written by this page: `{"v": 2, "lang": "DE",
/// "results": {...}}`. Older entries are the previous single-explanation
/// format and keep their old dialog.
Map<String, dynamic>? parseTutorEntry(String explanation) {
  try {
    final decoded = jsonDecode(explanation);
    if (decoded is Map<String, dynamic> && decoded['v'] == 2) return decoded;
  } catch (_) {}
  return null;
}

/// A one-line preview of a saved Tutor entry for the Tutor history list.
String tutorEntryPreview(Map<String, dynamic> entry) {
  final results = entry['results'];
  if (results is! Map) return '';
  for (final value in results.values) {
    if (value is List && value.isNotEmpty && value.first is Map) {
      final first = value.first as Map;
      final text = first['intro'] ?? first['correct'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
  }
  return '';
}

class TutorPage extends StatefulWidget {
  const TutorPage({super.key});

  @override
  State<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends State<TutorPage> {
  TutorRequest? _request;
  String _lang = 'DE';

  // Sentence picker.
  bool _splitting = false;
  List<TutorSentence>? _sentences;
  SentenceSelection? _selection;
  bool _picking = false;

  // Explanations.
  String? _text;
  TutorMode _mode = TutorMode.understanding;
  int _level = LevelPref.level;
  // Slider position while dragging; [_level] only changes on release, so a
  // drag does not request every level it passes.
  int? _dragLevel;
  final Map<String, List<Map<String, dynamic>>> _results = {};
  String? _loadingKey;
  // Markus, 2026-10-29 (Tutor waiting, option A): a bar that only shows
  // activity (no seconds, never full before the answer). Once the answer
  // takes clearly longer than usual on this phone, a calm note and
  // "Shorter answer" appear; nothing switches on its own.
  bool _showAnswerNow = false;
  bool _shortRequested = false;
  bool _failed = false;
  Timer? _waitTimer;
  final Stopwatch _waitWatch = Stopwatch();
  int _usualMs = _defaultAnswerMs;

  static const _answerTimesKey = 'tutor_answer_ms';
  static const _defaultAnswerMs = 15000;

  /// A wait that never ends is shown as an error instead (Markus: no
  /// endless waiting message). The accurate answer can take up to 2 min.
  static const _giveUpAfter = Duration(seconds: 150);

  /// The sentence split takes 5-13 s, 62 s at the worst peak so far
  /// (Alex's Vertex metrics, 29 Oct).
  static const _splitGiveUpAfter = Duration(seconds: 90);
  final List<TutorService> _inFlight = [];

  @override
  void initState() {
    super.initState();
    TutorLauncher.request.addListener(_onRequest);
    _loadUsualAnswerTime();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRequest());
  }

  @override
  void dispose() {
    TutorLauncher.request.removeListener(_onRequest);
    _cancelInFlight();
    super.dispose();
  }

  void _cancelInFlight() {
    _waitTimer?.cancel();
    for (final s in _inFlight) {
      s.cancel();
    }
    _inFlight.clear();
  }

  /// Results are cached per tab; Understanding also per level, so moving
  /// the slider back to a level already seen costs nothing.
  String _key(TutorMode mode) =>
      mode == TutorMode.understanding ? '${mode.name}@$_level' : mode.name;

  /// Explanation language: the UI language when the prompts support it,
  /// otherwise (Hungarian UI) the page's other language, else German.
  String _explanationLang(TutorRequest r) {
    if (r.cachedLang != null) return r.cachedLang!;
    final ui = Localizations.localeOf(context).languageCode.toUpperCase();
    if (TutorService.supportedLanguages.contains(ui)) return ui;
    final other = r.otherLangCode?.toUpperCase();
    if (other != null && TutorService.supportedLanguages.contains(other)) {
      return other;
    }
    return 'DE';
  }

  void _onRequest() {
    final r = TutorLauncher.request.value;
    if (r == null || !mounted || identical(r, _request)) return;
    _cancelInFlight();
    setState(() {
      _request = r;
      _lang = _explanationLang(r);
      _level = LevelPref.level;
      _sentences = null;
      _selection = null;
      _picking = false;
      _text = null;
      _results.clear();
      _loadingKey = null;
      _failed = false;
      _mode = TutorMode.understanding;
    });
    final cached = r.cached;
    if (cached != null) {
      cached.forEach((k, v) {
        if (v is List) {
          _results[k] = [
            for (final e in v)
              if (e is Map) Map<String, dynamic>.from(e),
          ];
        }
      });
      _startWith(r.text);
      return;
    }
    _prepare(r.text);
  }

  /// One sentence (no sentence end inside the text): explain right away.
  /// Otherwise split it and show the sentence picker.
  Future<void> _prepare(String text) async {
    final innerSentenceEnd = RegExp(r'[.!?…]["»”)]*\s+\S');
    if (!innerSentenceEnd.hasMatch(text)) {
      _startWith(text);
      return;
    }
    if (!await ensureWiuBalance(context)) return;
    setState(() => _splitting = true);
    try {
      final service = TutorService();
      final sentences = await service
          .splitSentences(text, _lang)
          .timeout(
            _splitGiveUpAfter,
            onTimeout: () {
              service.cancel();
              throw TimeoutException('Tutor sentence split');
            },
          );
      if (!mounted || _request?.text != text) return;
      if (sentences.length <= 1) {
        setState(() => _splitting = false);
        _startWith(text);
        return;
      }
      setState(() {
        _splitting = false;
        _sentences = sentences;
        _selection = SentenceSelection([
          for (final s in sentences) s.hu.length,
        ]);
        _picking = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _splitting = false;
        _failed = true;
      });
    }
  }

  void _applySelection() {
    final sel = _selection;
    if (sel == null || sel.isEmpty) return;
    final text = [
      for (var i = sel.first!; i <= sel.last!; i++) _sentences![i].hu,
    ].join(' ');
    if (text != _text) _results.clear();
    setState(() => _picking = false);
    _startWith(text);
  }

  void _startWith(String text) {
    setState(() {
      _text = text;
      _picking = false;
    });
    _run(_mode);
  }

  Future<void> _run(TutorMode mode) async {
    final text = _text;
    if (text == null) return;
    final key = _key(mode);
    if (_results.containsKey(key) || _loadingKey == key) return;
    if (!await ensureWiuBalance(context)) return;
    _cancelInFlight();
    setState(() {
      _loadingKey = key;
      _failed = false;
      _showAnswerNow = false;
      _shortRequested = false;
    });
    _waitWatch
      ..reset()
      ..start();
    _waitTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _loadingKey != key) return;
      if (_waitWatch.elapsed >= _giveUpAfter) {
        _cancelInFlight();
        setState(() {
          _loadingKey = null;
          _failed = true;
          _showAnswerNow = false;
        });
        return;
      }
      setState(() {
        _showAnswerNow = _waitWatch.elapsedMilliseconds >= _usualMs * 1.5;
      });
    });
    _fetch(mode, key, text, fast: false);
  }

  /// "Shorter answer": asks for the fast (no thinking) version alongside
  /// the accurate one; whichever arrives first is shown.
  void _answerNow() {
    final text = _text;
    final key = _loadingKey;
    if (text == null || key == null || _shortRequested) return;
    setState(() => _shortRequested = true);
    _fetch(_mode, key, text, fast: true);
  }

  // The median of the last 10 accurate answers on this phone.
  Future<void> _loadUsualAnswerTime() async {
    final prefs = await SharedPreferences.getInstance();
    final times =
        (prefs.getStringList(_answerTimesKey) ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .toList()
          ..sort();
    if (times.isEmpty || !mounted) return;
    _usualMs = times[times.length ~/ 2];
  }

  Future<void> _recordAnswerTime(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    final times = <String>[
      ...?prefs.getStringList(_answerTimesKey),
      '$ms',
    ];
    await prefs.setStringList(
      _answerTimesKey,
      times.sublist(math.max(0, times.length - 10)),
    );
    await _loadUsualAnswerTime();
  }

  int _pending = 0;

  Future<void> _fetch(
    TutorMode mode,
    String key,
    String text, {
    required bool fast,
  }) async {
    final service = TutorService();
    _inFlight.add(service);
    _pending++;
    try {
      final result = await service.explain(
        mode: mode,
        huText: text,
        langCode: _lang,
        level: _level,
        fast: fast,
      );
      if (!mounted || _loadingKey != key || _text != text) return;
      _cancelInFlight(); // the other request is no longer needed
      if (!fast) _recordAnswerTime(_waitWatch.elapsedMilliseconds);
      setState(() {
        _results[key] = result;
        _loadingKey = null;
        _showAnswerNow = false;
      });
      _saveToHistory(text);
    } catch (_) {
      if (!mounted || _loadingKey != key) return;
      // Only a failure of the last request still running is an error; a
      // cancelled or failed duplicate is not.
      if (_pending <= 1) {
        _waitTimer?.cancel();
        setState(() {
          _loadingKey = null;
          _failed = true;
          _showAnswerNow = false;
        });
      }
    } finally {
      _pending--;
      _inFlight.remove(service);
    }
  }

  void _saveToHistory(String text) {
    LearningStore.add(
      sentence: text,
      explanation: jsonEncode({'v': 2, 'lang': _lang, 'results': _results}),
    );
  }

  void _selectMode(TutorMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (!_picking) _run(mode);
  }

  Future<void> _setLevel(int level) async {
    await LevelPref.set(level);
    setState(() => _level = level);
    if (_mode == TutorMode.understanding && !_picking) _run(_mode);
  }

  // ───────────────────────────── UI ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Light tile background behind the page, as in Markus's mockup (the
    // same image the other pages' cards use).
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg-bright.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 12),
            Expanded(child: _body()),
            if (!_picking && _text != null && _mode == TutorMode.understanding)
              _levelBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final loc = AppLocalizations.of(context)!;
    final tabs = [
      (
        TutorMode.understanding,
        Icons.chat_bubble_outline,
        loc.tutorUnderstanding,
      ),
      (TutorMode.decoding, Icons.workspaces_outlined, loc.tutorDecoding),
      (TutorMode.focus, Icons.track_changes, loc.tutorFocus),
    ];
    // Mockup: the active tab is a green pill filling the full height of the
    // white bar from its edge; the other tabs are icons split by a thin line.
    const barHeight = 52.0;
    final children = <Widget>[];
    for (var i = 0; i < tabs.length; i++) {
      final (mode, icon, label) = tabs[i];
      final active = mode == _mode;
      final prevActive = i > 0 && tabs[i - 1].$1 == _mode;
      if (i > 0 && !active && !prevActive) {
        children.add(
          Container(width: 1, height: barHeight * 0.5, color: Colors.black26),
        );
      }
      children.add(
        active
            ? Expanded(
              flex: 3,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: _navGreen,
                  borderRadius: BorderRadius.circular(barHeight / 2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 26),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.robotoCondensed(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            : Expanded(
              flex: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(barHeight / 2),
                onTap: () => _selectMode(mode),
                child: SizedBox(
                  height: barHeight,
                  child: Tooltip(
                    message: label,
                    child: Icon(icon, color: _navGreen, size: 28),
                  ),
                ),
              ),
            ),
      );
    }
    return Row(
      children: [
        Image.asset('assets/images/bulb.png', width: 56, height: 56),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: barHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(barHeight / 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: Row(children: children),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_request == null) return const SizedBox.shrink();
    if (_splitting) {
      return const Center(child: CircularProgressIndicator(color: _navGreen));
    }
    if (_picking) return _picker();
    if (_failed) return _failure();
    final key = _key(_mode);
    final data = _results[key];
    if (data == null) return _loading();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((_sentences?.length ?? 0) > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _picking = true),
              icon: const Icon(Icons.format_list_bulleted, color: _navGreen),
              label: Text(
                AppLocalizations.of(context)!.tutorChooseSentences,
                style: GoogleFonts.robotoCondensed(
                  color: _navGreen,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final sentence in data)
                  switch (_mode) {
                    TutorMode.decoding => _decoderSentence(sentence),
                    _ => _explainedSentence(sentence),
                  },
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _loading() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                // Fills toward 90 % over the usual answer time, never to
                // the end: the answer replaces the bar when it arrives.
                value:
                    0.9 *
                    (1 -
                        math.exp(
                          -1.6 * _waitWatch.elapsedMilliseconds / _usualMs,
                        )),
                minHeight: 8,
                color: _navGreen,
                backgroundColor: _selectedFill,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _showAnswerNow ? loc.tutorTakingLonger : loc.tutorThinking,
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoCondensed(fontSize: 18),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: _showAnswerNow ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: OutlinedButton.icon(
              onPressed: _showAnswerNow && !_shortRequested ? _answerNow : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _navGreen,
                side: const BorderSide(color: _navGreen, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              // A spinner once tapped, so the tap visibly did something.
              icon:
                  _shortRequested
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _navGreen,
                        ),
                      )
                      : const Icon(Icons.short_text),
              label: Text(
                loc.tutorAnswerNow,
                style: GoogleFonts.robotoCondensed(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failure() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.serviceUnavailable,
            textAlign: TextAlign.center,
            style: GoogleFonts.robotoCondensed(fontSize: 18),
          ),
          const SizedBox(height: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: _navGreen, size: 32),
            onPressed: () {
              setState(() => _failed = false);
              if (_text == null && _request != null) {
                _prepare(_request!.text);
              } else {
                _run(_mode);
              }
            },
          ),
        ],
      ),
    );
  }

  // Understanding (Method 1) and Learning Focus (Mode 3): the sentence, an
  // optional intro, then the explained parts with an example each.
  Widget _explainedSentence(Map<String, dynamic> s) {
    final items = (s['items'] as List?) ?? const [];
    final intro = (s['intro'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _huSentence(s['hu'] as String? ?? ''),
          if (intro.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(intro, style: GoogleFonts.robotoCondensed(fontSize: 17)),
          ],
          for (final item in items)
            if (item is Map) _item(item),
        ],
      ),
    );
  }

  Widget _huSentence(String hu) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _navGreen, width: 3)),
      ),
      child: Text(
        hu,
        style: GoogleFonts.robotoCondensed(
          fontSize: 19,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _item(Map item) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item['term'] ?? ''}',
            style: GoogleFonts.robotoCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _navGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item['explanation'] ?? ''}',
            style: GoogleFonts.robotoCondensed(fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            '${item['example_hu'] ?? ''}',
            style: GoogleFonts.robotoCondensed(
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            '${item['example_translation'] ?? ''}',
            style: GoogleFonts.robotoCondensed(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // Decoding: three lines per sentence. "direct" is shown exactly as
  // returned (no Markdown): its _ and __ and superscripts carry meaning.
  Widget _decoderSentence(Map<String, dynamic> s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _huSentence(s['hu'] as String? ?? ''),
          const SizedBox(height: 10),
          Text(
            s['direct'] as String? ?? '',
            style: GoogleFonts.robotoCondensed(
              fontSize: 18,
              color: _navRed,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s['correct'] as String? ?? '',
            style: GoogleFonts.robotoCondensed(
              fontSize: 17,
              color: _navGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Sentence picker (Markus's mockup, 2026-10-09).
  Widget _picker() {
    final loc = AppLocalizations.of(context)!;
    final sel = _selection!;
    final sentences = _sentences!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.tutorChooseSentences,
          style: GoogleFonts.robotoCondensed(
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4EF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${sel.selectedChars}',
                      style: GoogleFonts.robotoCondensed(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color:
                            sel.selectedChars > SentenceSelection.maxChars
                                ? _navRed
                                : _navGreen,
                      ),
                    ),
                    TextSpan(
                      text: loc
                          .tutorCharCount(0, SentenceSelection.maxChars)
                          .replaceFirst('0', ''),
                      style: GoogleFonts.robotoCondensed(
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black26,
              ),
              const Icon(Icons.info_outline, color: _navGreen, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loc.tutorConsecutiveOnly,
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 15,
                    color: _navGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: sentences.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final selected = sel.isSelected(i);
              final tappable = sel.canTap(i);
              return Opacity(
                opacity: selected || tappable ? 1 : 0.4,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      tappable
                          ? () => setState(() => _selection = sel.toggle(i))
                          : null,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: selected ? _selectedFill : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _navGreen : Colors.black26,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sentences[i].hu,
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (sentences[i].translation.isNotEmpty)
                                Text(
                                  sentences[i].translation,
                                  style: GoogleFonts.robotoCondensed(
                                    fontSize: 15,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        selected
                            ? const CircleAvatar(
                              radius: 14,
                              backgroundColor: _navGreen,
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                            )
                            : Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black38,
                                  width: 1.5,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: sel.isEmpty ? 0.4 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: sel.isEmpty ? null : _applySelection,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: _navGreen,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.tutorApplySelection,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoCondensed(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Level slider (mockup: Sprachlevel ring, 01-99 track, value box).
  Widget _levelBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Tooltip(
            message: AppLocalizations.of(context)!.tutorLevel,
            // Markus's ring (2026-10-20), always without a number: the
            // level is shown in the value box on the right.
            child: Image.asset(
              'assets/images/sprachlevel.png',
              width: 56,
              height: 56,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Text('01', style: GoogleFonts.robotoCondensed(fontSize: 15)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: Colors.black26,
                        inactiveTrackColor: Colors.black12,
                        thumbColor: _navRed,
                        overlayColor: _navRed.withValues(alpha: 0.15),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 13,
                        ),
                      ),
                      child: Slider(
                        min: 1,
                        max: 99,
                        value: (_dragLevel ?? _level).toDouble(),
                        onChanged:
                            (v) => setState(() => _dragLevel = v.round()),
                        onChangeEnd: (v) {
                          _dragLevel = null;
                          _setLevel(v.round());
                        },
                      ),
                    ),
                  ),
                  Text('99', style: GoogleFonts.robotoCondensed(fontSize: 15)),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 52,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3),
              ],
            ),
            child: Text(
              (_dragLevel ?? _level).toString().padLeft(2, '0'),
              style: GoogleFonts.robotoCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
