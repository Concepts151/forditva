import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/document/document_translation_state.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_tts_service.dart';
import 'package:forditva/services/history_store.dart';
import 'package:forditva/flutter_gen/gen_l10n/app_localizations.dart';
import 'package:forditva/widgets/copied_toast.dart';
import 'package:forditva/widgets/edit_recording_modal.dart';
import 'package:forditva/widgets/wiu_gate.dart';
import 'package:forditva/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/gemini_translation_service.dart';
import '../services/third_language_pref.dart';

const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);

bool _explain = false;
bool _isTranslating = false;
const Color textGrey = Color(0xFF898888);

class DocumentPlaceholderPage extends StatefulWidget {
  const DocumentPlaceholderPage({super.key});

  @override
  State<DocumentPlaceholderPage> createState() =>
      _DocumentPlaceholderPageState();
}

class _DocumentPlaceholderPageState extends State<DocumentPlaceholderPage> {
  late final KeyboardVisibilityController _keyboardVisibilityController;
  late StreamSubscription<bool> _keyboardSubscription;
  bool _keyboardIsVisible = false;
  final _ttsService = GeminiTtsService();
  ap.AudioPlayer? _ttsAudioPlayer; // 👈 audio player instance
  double _zoomLevel = 1.0; // Default zoom factor

  late final FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  final bool _isListening = false;
  final ScrollController _scrollController = ScrollController();
  final GeminiTranslator _gemini = GeminiTranslator();
  late TextEditingController _inputController;
  late FocusNode _inputFocusNode;

  String _explanationLevel = 'A2'; // default level

  Language _leftLang = Language.english;
  Language _rightLang = Language.hungarian;

  // Public so the nav bar (main.dart, via a GlobalKey) can reactively enable
  // the Tutor bulb only while Hungarian text is actually present on this page.
  final ValueNotifier<bool> hasHungarianText = ValueNotifier(false);

  void _updateHasHungarianText() {
    // _rightLang is always the SOURCE (holds _inputController.text) and
    // _leftLang is always the TARGET (holds _translatedText) — see
    // _translateText. This was checking them backwards (Markus, 2026-07-11:
    // recorded English -> Hungarian, but the bulb stayed disabled).
    final hungarianText =
        _rightLang == Language.hungarian
            ? _inputController.text
            : _leftLang == Language.hungarian
            ? _translatedText
            : '';
    final has = hungarianText.trim().isNotEmpty;
    if (has == hasHungarianText.value) return;
    // Called from build(), and the nav bar rebuilds on this notifier, so
    // setting it mid-build threw "setState() called during build". Apply it
    // right after the frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) hasHungarianText.value = has;
    });
  }

  final Map<Language, String> _flagPaths = {
    for (final lang in Language.values) lang: lang.flagPath,
  };

  final Map<Language, String> _langLabels = {
    for (final lang in Language.values) lang: lang.label,
  };
  String instructionForLang(Language lang) {
    return "The following text is in ${lang.fullName}. Read it aloud in "
        "${lang.fullName} with a natural native ${lang.fullName} accent.";
  }

  String _localeFor(Language lang) {
    switch (lang) {
      case Language.english:
        return 'en-US';
      case Language.german:
        return 'de-DE';
      case Language.hungarian:
        return 'hu-HU';
      case Language.dutch:
        return 'nl-NL';
      case Language.french:
        return 'fr-FR';
      case Language.spanish:
        return 'es-ES';
      case Language.russian:
        return 'ru-RU';
      case Language.italian:
        return 'it-IT';
    }
  }

  String _translatingText(Language lang) {
    switch (lang) {
      case Language.hungarian:
        return 'Fordítás…';
      case Language.german:
        return 'Übersetzen…';
      case Language.english:
      case Language.dutch:
      case Language.french:
      case Language.spanish:
      case Language.russian:
      case Language.italian:
        return 'Translating…';
    }
  }

  String _detectedLangDialog(Language lang, String detectedLangName) {
    switch (lang) {
      case Language.hungarian:
        return "Az észlelt nyelv: $detectedLangName. Szeretné módosítani a beállítást erre?";
      case Language.german:
        return "Die erkannte Sprache ist $detectedLangName. Sollen wir deine Einstellung darauf anpassen?";
      case Language.english:
      case Language.dutch:
      case Language.french:
      case Language.spanish:
      case Language.russian:
      case Language.italian:
        return "The detected language is $detectedLangName. Should we change your setting to this?";
    }
  }

  bool _isSpeaking = false;
  Future<void> _speak() async {
    if (_translatedText.isEmpty) return;

    try {
      final instructions = instructionForLang(_leftLang);
      final file = await _ttsService.synthesizeSpeech(
        text: _translatedText,
        voice: "onyx",
        instructions: instructions,
        langCode: _leftLang.code,
      );

      if (!await file.exists() || (await file.length()) == 0) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("TTS failed: ${file.path}")));
        }
        return;
      }

      _ttsAudioPlayer ??= ap.AudioPlayer();
      await _ttsAudioPlayer!.stop();

      late final StreamSubscription sub;
      sub = _ttsAudioPlayer!.onPlayerStateChanged.listen((state) {
        if (!mounted) return;

        if (state == ap.PlayerState.playing) {
          setState(() => _isSpeaking = true);
        } else if (state == ap.PlayerState.completed ||
            state == ap.PlayerState.stopped) {
          setState(() => _isSpeaking = false);
          sub.cancel();
        }
      });

      await _ttsAudioPlayer!.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("TTS failed: $e")));
        setState(() => _isSpeaking = false);
      }
    }
  }

  /// Stops playback in place — the conversation page shows a stop-square
  /// while playing (tap to stop); this page was showing a spinning circle
  /// instead with no way to stop (Markus, 2026-07-11: "why the circle
  /// spinner instead of the square that means stop").
  Future<void> _stopSpeaking() async {
    await _ttsAudioPlayer?.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  void initState() {
    super.initState();
    _inputFocusNode = FocusNode();

    final locale =
        WidgetsBinding.instance.window.locale; // safer than waiting for context
    final pair = getInitialLangPair(locale);

    // Prefer languages carried over from the conversation page (so copied
    // content is spoken in the correct language); otherwise fall back to the
    // locale-derived pair.
    _leftLang = DocumentTranslationState.leftLang ?? pair[0];
    _rightLang = DocumentTranslationState.rightLang ?? pair[1];
    DocumentTranslationState.leftLang = null;
    DocumentTranslationState.rightLang = null;
    _inputController = TextEditingController(
      text: DocumentTranslationState.inputText,
    );
    _translatedText = DocumentTranslationState.translatedText;
    _keyboardVisibilityController = KeyboardVisibilityController();
    _keyboardSubscription = _keyboardVisibilityController.onChange.listen((
      bool visible,
    ) {
      setState(() {
        _keyboardIsVisible = visible;
      });
    });
    _speech = stt.SpeechToText();

    _flutterTts = FlutterTts();
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    // 2. TTS event hooks
    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
  }

  Language _langFromCode(String code) {
    return Language.values.firstWhere(
      (lang) => lang.code.toLowerCase() == code.toLowerCase(),
      orElse: () => _leftLang, // fallback to current
    );
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();

    _ttsAudioPlayer?.dispose();

    _inputController.dispose();
    _scrollController.dispose();
    _keyboardSubscription.cancel();
    hasHungarianText.dispose();

    super.dispose();
  }

  /// Opens the exact same edit/recording panel used on the conversation page
  /// (Markus, 2026-07-11: "why aren't you copying them one to one here to
  /// the edit mode of the document page" — tapping edit or mic on this page
  /// now switches to that identical panel instead of recording inline here).
  /// [autoStartRecording] is set when opened via the mic icon specifically,
  /// so recording begins immediately rather than requiring another tap.
  void _showEditModal({bool autoStartRecording = false}) {
    _ttsAudioPlayer?.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: EditTextModal(
            initialText: _inputController.text,
            fromLang: _rightLang,
            toLang: _leftLang,
            gemini: _gemini,
            autoStartRecording: autoStartRecording,
            isTextInLanguage:
                (text) => isTextInLanguage(text, _langLabels[_rightLang]!, _gemini),
            onEdited: ({required String edited, required String translated}) {
              setState(() {
                _inputController.text = edited;
                _translatedText = translated;
                DocumentTranslationState.inputText = edited;
                DocumentTranslationState.translatedText = translated;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.robotoCondensed(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content ?? '',
            style: GoogleFonts.robotoCondensed(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _translatedText = '';

  void _switchLanguages() {
    setState(() {
      final tempLang = _rightLang;
      _rightLang = _leftLang;
      _leftLang = tempLang;

      final tempText = _inputController.text;
      _inputController.text = _translatedText;
      _translatedText = tempText;

      final input = _inputController.text.trim();
      if (input.isNotEmpty) _translateText(input);
    });
  }

  void _showExplanationModal(String initialExplanation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        String explanationText = initialExplanation;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void fetchExplanation(String level) async {
              setModalState(() => isLoading = true);
              try {
                final newExp = await _gemini.translate(
                  _inputController.text.trim(),
                  _langLabels[_leftLang]!,
                  _langLabels[_rightLang]!,
                  explain: true,
                  level: level,
                  // The Tutor explanation must be in the app's UI language
                  // (e.g. German), not whichever language the document's
                  // input happens to be set to.
                  uiLanguage: Localizations.localeOf(context).languageCode.toUpperCase(),
                );
                setModalState(() {
                  explanationText = newExp;
                });
              } catch (_) {
                setModalState(() {
                  explanationText = 'Failed to load explanation.';
                });
              } finally {
                setModalState(() => isLoading = false);
              }
            }

            // parsing logic for structured Gemini JSON
            Map<String, dynamic> parsed = {};
            try {
              final cleanJson = stripCodeFence(explanationText);
              parsed = cleanJson.isNotEmpty ? jsonDecode(cleanJson) : {};
            } catch (e) {
              parsed = {};
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 0.5, color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- HEADER WITH LOGO & TUTOR ---
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Tutor",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: navGreen,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() => _explain = false);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child:
                            isLoading
                                ? const Center(child: GifLoader(size: 80))
                                : parsed.isEmpty
                                ? Text(explanationText)
                                : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSection(
                                        AppLocalizations.of(
                                          context,
                                        )!.grammarExplanation,
                                        parsed["grammar_explanation"],
                                      ),
                                      _buildSection(
                                        AppLocalizations.of(
                                          context,
                                        )!.keyVocabulary,
                                        parsed["key_vocabulary"],
                                      ),
                                      _buildSection(
                                        AppLocalizations.of(
                                          context,
                                        )!.translationHeading,
                                        parsed["translation"],
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ),

                    const Divider(thickness: 1),

                    // Level selector
                    Container(
                      color: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children:
                            ['A1', 'A2', 'B1'].map((level) {
                              final active = _explanationLevel == level;
                              return GestureDetector(
                                onTap: () {
                                  setModalState(
                                    () => _explanationLevel = level,
                                  );
                                  fetchExplanation(level);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active ? navRed : null,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    level,
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color:
                                          active ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Language _next(Language current, Language other) {
    final list = [
      Language.hungarian,
      Language.german,
      ThirdLanguagePref.current,
    ];
    int i = list.indexOf(current);
    Language next = list[(i + 1) % list.length];
    if (next == other) {
      next = list[(i + 2) % list.length];
    }
    return next;
  }

  /// Map our Language enum into Lingvanex’s `xx_XX` codes
  String _lingvanexCode(Language lang) {
    // reuse your existing _localeFor() which returns "en-US", "de-DE", etc.
    return _localeFor(lang).replaceAll('-', '_');
  }

  Future<void> _translateText(String input) async {
    if (!await ensureWiuBalance(context)) return;

    final fromLang = _rightLang;
    final toLang = _leftLang;
    final from = _langLabels[fromLang]!; // used to be _leftLang
    final to = _langLabels[toLang]!; // used to be _rightLang

    final String currentText = _inputController.text.trim();

    setState(() {
      _isTranslating = true;
      if (!_explain) _translatedText = '';
    });

    try {
      final result = await _gemini.translate(
        currentText,
        from,
        to,
        explain: false,
      );

      if (!mounted) return;

      if (_explain) {
        _showExplanationModal(result);
      } else {
        setState(() {
          _translatedText = result;
          DocumentTranslationState.translatedText = result;
        });
        unawaited(
          HistoryStore.save(
            input: currentText,
            output: result,
            from: fromLang,
            to: toLang,
          ),
        );
      }
    } catch (e) {
      debugPrint('Translation error: $e');
      if (_explain) {
        _showExplanationModal('Failed to load explanation.');
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _showLoaderBeforeModal(
    Future<String> Function() loadExplanation,
  ) async {
    // Show fullscreen loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: GifLoader(size: 80)),
    );

    // Run the translation and close loader when done
    final explanation = await loadExplanation();

    if (!mounted) return;

    Navigator.of(context).pop(); // Close the loader
    _showExplanationModal(explanation); // Show modal
  }

  // Tutor: called by the nav bar's bulb button (main.dart, via GlobalKey).
  // Explains whichever Hungarian text is currently on this page.
  void openTutor() {
    final hungarianText =
        _leftLang == Language.hungarian
            ? _inputController.text.trim()
            : _rightLang == Language.hungarian
            ? _translatedText.trim()
            : '';
    if (hungarianText.isEmpty) return;
    _showLoaderBeforeModal(() async {
      try {
        return await _gemini.translate(
          hungarianText,
          _langLabels[_leftLang]!,
          _langLabels[_rightLang]!,
          explain: true,
          level: _explanationLevel,
          uiLanguage: Localizations.localeOf(context).languageCode.toUpperCase(),
        );
      } catch (_) {
        return 'Failed to load explanation.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateHasHungarianText();
    final media = MediaQuery.of(context);
    final bool keyboardIsOpen = media.viewInsets.bottom > 50;

    final double cardWidth = media.size.width.clamp(0, 486);
    final double cardHeight = media.size.height * 0.8;
    String inputText = _inputController.text;
    String outText = _translatedText;
    // 1) compute iconSize once at the top of your build:
    final screenWidth = MediaQuery.of(context).size.width;
    // ~9.5% of screen width → ~34 dp on a 360 dp screen. Clamp so it never gets too small/large.
    final double iconSize = (screenWidth * 0.085).clamp(24.0, 48.0);
    double inputFontSize = dynamicFontSize(inputText);
    double outputFontSize = dynamicFontSize(outText);
    final double bottomReserve =
        _keyboardIsVisible
            ? 60.0
            : iconSize + 16.0; // iconSize + some extra margin
    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      // The card height used to be MediaQuery.of(context).size.height (the
      // full device screen), not this page's actual available space, so it
      // always assumed more room than Scaffold really gave it and had to
      // scroll to show everything, unlike the Image page which sizes to its
      // real constraint and always fits (Markus, 2026-07-14: "there should
      // be no scrolling like the document page, it must fit").
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          // Was Padding(top: 10) here, an extra offset only this page had —
          // Conversation and Image have no equivalent, so Document's top
          // edge sat visibly lower than the other two (Markus, 2026-07-14).
          return Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: cardWidth,
                height: outerConstraints.maxHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalHeight = constraints.maxHeight;
                // Trimmed so this page's top/bottom gaps line up with the
                // others (spacing audit, 2026-07-13): topMargin 20 -> 8 (the
                // global body padding already supplies the main top gap),
                // bottomMargin 40 -> 8 (the nav-bar white area already
                // supplies the bottom gap).
                const topMargin = 8.0;
                const bottomMargin = 8.0;
                // Fixed content height of the language-switcher row below the
                // top card: padding (15+15) + the flag/text row (~40).
                const switcherHeight = 70.0;
                final cardHeight =
                    _keyboardIsVisible
                        // Only the input card is shown while the keyboard is
                        // up; let it fill the space instead of staying pinned
                        // at half height, which left a large blank gap
                        // between the switcher and the keyboard.
                        ? totalHeight - topMargin - switcherHeight - 16.0
                        // Was subtracting spacingBetween (10) here instead of
                        // the switcher's real height (70), so the two cards
                        // plus switcher always summed to ~60px more than the
                        // container's actual height, forcing a scroll no
                        // matter what the outer container sizing was (Markus,
                        // 2026-07-14: "document is still scrolling").
                        : (totalHeight -
                                topMargin -
                                bottomMargin -
                                switcherHeight) /
                            2;

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top card
                      Container(
                        height: cardHeight,
                        margin: const EdgeInsets.fromLTRB(12, topMargin, 12, 0),
                        child: _buildTopInputCard(),
                      ),

                      // Switcher panel
                      _buildSwitcherPanel(),

                      // Bottom card (only if keyboard not visible)
                      if (!_keyboardIsVisible)
                        Container(
                          height: cardHeight,
                          margin: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            bottomMargin,
                          ),
                          child: _buildBottomOutputCard(),
                        ),
                    ],
                  ),
                );
                  },
                ),
              ),
            );
        },
      ),
    );
  }

  /// Tapping mic switches straight to the edit panel and starts recording
  /// there (Markus, 2026-07-11: "when you clicks on record, the microphone,
  /// it will switch to the edit mode and we'll start to record" — recording
  /// must not happen inline in this view, only inside the shared modal).
  Widget _micControl(double iconSize) {
    return GestureDetector(
      onTap: () => _showEditModal(autoStartRecording: true),
      child: Image.asset('assets/images/b_microphone.png', width: iconSize),
    );
  }

  Widget _buildTopInputCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 0.5),
        image: const DecorationImage(
          image: AssetImage('assets/images/bg-bright.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double iconSize = (MediaQuery.of(context).size.width * 0.085)
              .clamp(24.0, 48.0);
          final double bottomReserve =
              _keyboardIsVisible ? 60.0 : iconSize + 16.0;
          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: bottomReserve),
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // Tapping the text opens the same edit panel as the
                        // pencil/mic icons (Markus, 2026-07-11: "this edit
                        // panel is there when I click on the text input box —
                        // it should be the other panel we just switched to").
                        onTap: () => _showEditModal(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          constraints: const BoxConstraints(minHeight: 180),
                          width: double.infinity,
                          child: TextField(
                            controller: _inputController,
                            focusNode: _inputFocusNode,
                            // Display only — all editing now happens in the
                            // shared modal, so this never summons a keyboard.
                            readOnly: true,
                            showCursor: false,
                            maxLines: null,
                            style: GoogleFonts.robotoCondensed(
                              fontSize:
                                  dynamicFontSize(_inputController.text) *
                                  _zoomLevel,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.3,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      if (!_inputFocusNode.hasFocus &&
                          _inputController.text.trim().isEmpty)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: IgnorePointer(
                              child: Text(
                                AppLocalizations.of(context)!.documentPlaceholder,
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 25 * _zoomLevel,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!_keyboardIsVisible)
                Positioned(
                  bottom: 8,
                  left: 45,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Expanded so the recording waveform (inside
                      // _recordingControl) has room to fill the space.
                      Expanded(
                        child: Row(
                          children: [
                            // Trash — clears the input box.
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _inputController.clear();
                                  _translatedText = '';
                                  DocumentTranslationState.inputText = '';
                                  DocumentTranslationState.translatedText = '';
                                });
                              },
                              child: Image.asset(
                                'assets/png24/black/b_garbage.png',
                                width: iconSize,
                              ),
                            ),
                            // Markus, 2026-07-11 (voice note): spread the
                            // icons further apart, there's room for it.
                            const SizedBox(width: 20),
                            GestureDetector(
                              onTap: () async {
                                final data = await Clipboard.getData(
                                  'text/plain',
                                );
                                if (data?.text != null &&
                                    data!.text!.trim().isNotEmpty) {
                                  setState(() {
                                    // Unfocused: replace the whole text box.
                                    final pasted = data.text!.trim();
                                    _inputController.text = pasted;
                                    _inputController
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(offset: pasted.length),
                                    );
                                    DocumentTranslationState.inputText =
                                        pasted;
                                  });
                                  // Translate right away (Markus, video of
                                  // 2026-09-29: "it should translate in the
                                  // lower area"). Pasting only filled the
                                  // box before.
                                  _translateText(data.text!.trim());
                                }
                              },
                              child: Image.asset(
                                'assets/images/paste.png',
                                width: iconSize,
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Edit — opens the shared edit panel (Markus,
                            // 2026-07-11: "clicking on the pencil, it will go
                            // to the edit mode").
                            GestureDetector(
                              onTap: () => _showEditModal(),
                              child: Image.asset(
                                'assets/png24/black/b_edit.png',
                                width: iconSize,
                              ),
                            ),
                            const SizedBox(width: 20),
                            _micControl(iconSize),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // 🎙 Only show when keyboard is visible
              if (_keyboardIsVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Group ❌ | 📋 | 🎙 with spacing. Expanded so the
                        // recording waveform (inside _recordingControl) has
                        // room to fill the space up to the check icon.
                        Expanded(
                          child: Row(
                            children: [
                              // ❌ Cancel icon — just dismiss the keyboard,
                              // keep the text (does NOT delete).
                              GestureDetector(
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                },
                                child: Image.asset(
                                  'assets/images/close.png',
                                  width: iconSize,
                                ),
                              ),
                              // Markus, 2026-07-11 (voice note): spread the
                              // icons further apart, there's room for it.
                              const SizedBox(width: 18),

                              // 📋 Paste icon
                              GestureDetector(
                                onTap: () async {
                                  final data = await Clipboard.getData(
                                    'text/plain',
                                  );
                                  if (data?.text != null &&
                                      data!.text!.trim().isNotEmpty) {
                                    setState(() {
                                      // Focused: insert at the cursor position.
                                      final pasted = data.text!.trim();
                                      final text = _inputController.text;
                                      final sel = _inputController.selection;
                                      final start =
                                          sel.start >= 0
                                              ? sel.start
                                              : text.length;
                                      final end =
                                          sel.end >= 0 ? sel.end : text.length;
                                      final updated = text.replaceRange(
                                        start,
                                        end,
                                        pasted,
                                      );
                                      _inputController.text = updated;
                                      _inputController
                                          .selection = TextSelection.collapsed(
                                        offset: start + pasted.length,
                                      );
                                    });
                                  }
                                },
                                child: Image.asset(
                                  'assets/images/paste.png',
                                  width: iconSize,
                                ),
                              ),
                              const SizedBox(width: 18),

                              // 🎙 Mic icon — opens the shared edit panel
                              _micControl(iconSize),
                            ],
                          ),
                        ),

                        // ✅ Check icon (flush right)
                        GestureDetector(
                          onTap: () async {
                            final input = _inputController.text.trim();
                            if (input.isEmpty) return;

                            final detected = await _gemini.detectLanguage(
                              input,
                            );
                            final expected = _rightLang.code;

                            if (!context.mounted) return;

                            // Only a confident, supported answer may prompt a
                            // language switch: UNKNOWN or garbage would fall
                            // back to _leftLang in _langFromCode and offer a
                            // nonsense change.
                            final isSupported = Language.values.any(
                              (l) => l.code.toUpperCase() == detected,
                            );
                            if (isSupported && detected != expected) {
                              final detectedLang = _langFromCode(detected);
                              final currentLocale =
                                  Localizations.localeOf(context).languageCode;

                              String dialogText;
                              switch (currentLocale) {
                                case 'de':
                                  dialogText =
                                      'Die erkannte Sprache ist ${detectedLang.label}. Sollen wir deine Einstellung darauf anpassen?';
                                  break;
                                case 'hu':
                                  dialogText =
                                      'A felismerte nyelv: ${detectedLang.label}. Szeretné, hogy ehhez igazítsuk a beállítást?';
                                  break;
                                case 'en':
                                default:
                                  dialogText =
                                      'The detected language is ${detectedLang.label}. Should we change your setting to this?';
                                  break;
                              }

                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    content: Text(dialogText),
                                    actions: [
                                      IconButton(
                                        icon: Image.asset(
                                          'assets/images/close.png',
                                          width: iconSize,
                                          color: navRed,
                                        ),
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                      ),
                                      IconButton(
                                        icon: Image.asset(
                                          'assets/images/check.png',
                                          width: iconSize,
                                          color: navGreen,
                                        ),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          WidgetsBinding.instance.addPostFrameCallback((
                                            _,
                                          ) async {
                                            if (mounted) {
                                              setState(
                                                () => _rightLang = detectedLang,
                                              );

                                              // Translate with the corrected
                                              // source language (this also
                                              // records it in History).
                                              FocusScope.of(this.context).unfocus();
                                              _translateText(
                                                _inputController.text.trim(),
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                              return;
                            }

                            // Language matches: translate now. Nothing else
                            // translates text typed into this box, so this
                            // check used to save a stale (often empty)
                            // translation and show none. _translateText also
                            // records it in History.
                            FocusScope.of(context).unfocus();
                            _translateText(input);
                          },
                          child: Image.asset(
                            'assets/images/check.png',
                            width: iconSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomOutputCard() {
    final double iconSize = (MediaQuery.of(context).size.width * 0.085).clamp(
      24.0,
      48.0,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 0.5),
        image: const DecorationImage(
          image: AssetImage('assets/images/bg-bright.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child:
                _isTranslating
                    ? Center(
                      child: Image.asset(
                        'assets/images/loader.gif',
                        width: 80,
                        height: 80,
                      ),
                    )
                    : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showEditModal(),
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            controller: _scrollController,
                            child: Text(
                              _translatedText,
                              style: GoogleFonts.robotoCondensed(
                                fontSize:
                                    dynamicFontSize(_translatedText) *
                                    _zoomLevel,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
          Row(
            children: [
              IconButton(
                icon: Image.asset(
                  'assets/png24/black/b_copy.png',
                  width: iconSize,
                ),
                onPressed: () {
                  if (_translatedText.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: _translatedText));
                    showCopiedToast(
                      context,
                      AppLocalizations.of(context)!.copiedToClipboard,
                    );
                  }
                },
              ),
              IconButton(
                icon: Image.asset('assets/png24/black/b_share.png', width: 40),
                onPressed: () {
                  if (_translatedText.isNotEmpty) {
                    Share.share(_translatedText);
                  }
                },
              ),
              IconButton(
                icon: Image.asset(
                  'assets/png24/black/b_fullscreen.png',
                  width: iconSize,
                ),
                onPressed: () {
                  if (_translatedText.isNotEmpty) {
                    // 👇 Unfocus the input to prevent cursor from reappearing later
                    FocusScope.of(context).unfocus();

                    showDialog(
                      context: context,
                      builder: (_) => LandscapeZoomModal(text: _translatedText),
                    );
                  }
                },
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  if (_isSpeaking) {
                    await _stopSpeaking();
                  } else if (_translatedText.isNotEmpty) {
                    await _speak();
                  }
                },
                child:
                    _isSpeaking
                        // Same stop-square asset the conversation page uses
                        // (Markus, 2026-07-12: only icons from his asset
                        // folder), tinted black since w_stop.png is white and
                        // was made for the dark conversation-page card.
                        ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            'assets/images/w_stop.png',
                            width: iconSize,
                            height: iconSize,
                          ),
                        )
                        : Image.asset(
                          'assets/png24/black/b_speaker.png',
                          width: iconSize,
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap:
                () => setState(() {
                  _rightLang = _next(_rightLang, _leftLang);
                  final input = _inputController.text.trim();
                  if (input.isNotEmpty) _translateText(input);
                }),
            child: Row(
              children: [
                Text(
                  _langLabels[_rightLang]!,
                  style: GoogleFonts.roboto(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Image.asset(_flagPaths[_rightLang]!, width: 60, height: 40),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _switchLanguages,
            child: Image.asset(
              'assets/png24/black/b_change_flat.png',
              width: 60,
              height: 40,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap:
                () => setState(() {
                  _leftLang = _next(_leftLang, _rightLang);
                  final input = _inputController.text.trim();
                  if (input.isNotEmpty) _translateText(input);
                }),

            child: Row(
              children: [
                Image.asset(_flagPaths[_leftLang]!, width: 60, height: 40),
                const SizedBox(width: 4),
                Text(
                  _langLabels[_leftLang]!,
                  style: GoogleFonts.roboto(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class LandscapeZoomModal extends StatelessWidget {
  final String text;
  const LandscapeZoomModal({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.height - 40;
    final height = MediaQuery.of(context).size.width * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: RotatedBox(
        quarterTurns: 1,
        child: Stack(
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, left: 20),
                  child: Text(
                    text,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              bottom: 8, // 👈 bottom of landscape = left in portrait
              right:
                  8, // 👈 left side of the rotated box (i.e. bottom-left in portrait)
              child: IconButton(
                icon: Image.asset(
                  'assets/images/close.png',
                  width: 40,
                  height: 40,
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaticWave extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(90, 50), painter: _GreenWavePainter());
  }
}

class _GreenWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final dx = 8 + i * 14.0;
      final waveHeight = (i % 2 == 0) ? 20.0 : 35.0;
      canvas.drawLine(
        Offset(dx, size.height / 2 - waveHeight / 2),
        Offset(dx, size.height / 2 + waveHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
