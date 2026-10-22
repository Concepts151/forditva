import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:forditva/conversation_state.dart';
import 'package:forditva/document/document_translation_state.dart';
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/services/gemini_tts_service.dart';
import 'package:forditva/services/history_store.dart';
import 'package:forditva/widgets/error_dialog.dart';
import 'package:forditva/widgets/wiu_gate.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:forditva/tutor/tutor_page.dart'; // your Gemini client
import 'package:forditva/services/third_language_pref.dart';
import 'package:forditva/spacing.dart';
import 'package:forditva/widgets/edit_recording_modal.dart';
import 'package:forditva/widgets/recording_modal.dart'; // adjust path as needed
import 'package:forditva/widgets/copied_toast.dart';
import 'package:forditva/widgets/translation_card.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

typedef OnEditAndTranslate =
    void Function({required String edited, required String translated});

extension LanguageRecordingText on Language {
  String get beginRecording {
    switch (this) {
      case Language.hungarian:
        return 'Kezdje a felvételt…';
      case Language.german:
        return 'Beginnen Sie die Aufnahme…';
      case Language.english:
      case Language.dutch:
      case Language.french:
      case Language.spanish:
      case Language.russian:
      case Language.italian:
        return 'Begin recording…';
    }
  }
}

String instructionForLang(Language lang) {
  // Force the TTS to pronounce in the target language. The soft
  // "speak as this dialect" hint was being ignored, so French text was read
  // with a Hungarian accent (Markus's voice note). Name the language firmly.
  return "The following text is in ${lang.fullName}. "
      "Read it aloud in ${lang.fullName} with a natural native "
      "${lang.fullName} accent and pronunciation. Do not use any other "
      "language's accent.";
}

// Add this OUTSIDE your classes
// Markus's own bordered square flag: the `_W` (white border) variant on dark
// cards, `_B` (anthracite border) on light ones. Clipped to rounded corners so
// the JPG's opaque corners don't show against the card.
Widget borderedFlag(
  Language lang, {
  required bool whiteBorder,
  double size = 30,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: Image.asset(
      'assets/flags/${lang.label}_${whiteBorder ? 'W' : 'B'}.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

// Written by the audio listeners but never read. Kept (with their setState
// calls) so this cleanup cannot change when the page rebuilds.
// ignore: unused_element
bool _isAudioPlaying = false;

/// Clips a card to a stepped seam that runs through the switch button.
///
/// The seam is flat (horizontal) on both sides at two different heights, with a
/// short step that is hidden behind the switch button in the centre:
///   left side  -> at the TOP of the switch    (bright card reaches up to here)
///   right side -> at the BOTTOM of the switch  (dark card reaches down to here)
///
/// For the top (dark) card [keepTop] is true (keep everything above the seam);
/// for the bottom (bright) card it is false (keep everything below). Both cards
/// use the same seam in screen space, so they tile along it.
class _SeamClipper extends CustomClipper<Path> {
  final double switchSize;
  final bool keepTop;

  const _SeamClipper({required this.switchSize, required this.keepTop});

  @override
  Path getClip(Size size) {
    final centerX = size.width / 2;
    // Width of the slanted transition. Kept narrow enough to sit behind the
    // switch button's flat face so its corners never peek out.
    final stepHalf = switchSize / 2 - 18;

    final path = Path();
    if (keepTop) {
      // Dark card: flat at the top-of-switch level on the left, flat at the
      // bottom-of-switch level on the right, keep everything above.
      final topLevel = size.height - switchSize; // top of switch
      final bottomLevel = size.height; // bottom of switch
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, bottomLevel);
      path.lineTo(centerX + stepHalf, bottomLevel);
      path.lineTo(centerX - stepHalf, topLevel);
      path.lineTo(0, topLevel);
    } else {
      // Bright card: flat at the top-of-switch level (y 0) on the left, flat at
      // the bottom-of-switch level (y switchSize) on the right, keep below.
      // 1px of slack upward so the seam has no anti-aliased hairline.
      path.moveTo(0, -1);
      path.lineTo(centerX - stepHalf, -1);
      path.lineTo(centerX + stepHalf, switchSize - 1);
      path.lineTo(size.width, switchSize - 1);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_SeamClipper oldClipper) =>
      oldClipper.switchSize != switchSize || oldClipper.keepTop != keepTop;
}

class TextPage extends StatefulWidget {
  /// Called when the user taps the document icon on the bottom card, after
  /// both cards' current text has been copied into Document mode.
  final VoidCallback? onOpenDocument;

  const TextPage({super.key, this.onOpenDocument});

  @override
  State<TextPage> createState() => _TextPageState();
}

/// ==================== TextPage ====================
class _TextPageState extends State<TextPage> {
  final TextEditingController _inputController = TextEditingController();
  String _translation = '';
  // ▶︎ spinner while Gemini runs
  bool _isTranslating = false;
  bool _isAudioLoadingInput = false; // For the input card play button
  bool _isAudioLoadingOutput = false; // For the output card play button
  ap.AudioPlayer? _audioPlayer;
  bool _isInputPlaying = false;
  bool _isOutputPlaying = false;
  ap.AudioPlayer? _inputAudioPlayer;
  ap.AudioPlayer? _outputAudioPlayer;

  // Cache the last synthesized audio per card, keyed by the text it was
  // generated for. Re-pressing play on unchanged text skips the TTS call
  // entirely instead of re-synthesizing (removes the delay before playback).
  String? _inputAudioCacheText;
  File? _inputAudioCacheFile;
  String? _outputAudioCacheText;
  File? _outputAudioCacheFile;

  // ▶︎ your Gemini client
  final GeminiTranslator _gemini = GeminiTranslator();
  final _ttsService = GeminiTtsService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    final pair = getInitialLangPair(locale);
    setState(() {
      _leftLanguage = ThirdLanguagePref.normalize(pair[0]);
      _rightLanguage = ThirdLanguagePref.normalize(pair[1]);
    });
  }

  /// The third language changed in Settings (this page stays loaded under
  /// the Settings screen): switch to it right away and translate into it.
  void _onThirdLanguageChanged() {
    if (!mounted) return;
    final left = ThirdLanguagePref.normalize(_leftLanguage);
    final right = ThirdLanguagePref.normalize(_rightLanguage);
    if (left == _leftLanguage && right == _rightLanguage) return;
    final leftChanged = left != _leftLanguage;
    setState(() {
      _leftLanguage = left;
      _rightLanguage = right;
    });
    autoTranslateOnLanguageChange(leftChanged: leftChanged, playTTS: false);
  }

  Future<void> _playInputSound() async {
    // Stop the other audio player if playing
    await _outputAudioPlayer?.stop();
    setState(() {
      _isOutputPlaying = false;
    });

    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = true;
    });
    _inputAudioPlayer ??= ap.AudioPlayer();

    File file;
    if (_inputAudioCacheText == _translation && _inputAudioCacheFile != null) {
      file = _inputAudioCacheFile!;
    } else {
      try {
        file = await _ttsService.synthesizeSpeech(
          text: _translation,
          voice: "onyx",
          instructions: instructionForLang(_rightLanguage),
          langCode: _rightLanguage.code,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isInputPlaying = false);
        showTtsError(context, e);
        return;
      }
      _inputAudioCacheText = _translation;
      _inputAudioCacheFile = file;
    }

    late final StreamSubscription sub;
    sub = _inputAudioPlayer!.onPlayerStateChanged.listen((state) {
      // The page can be closed mid-playback (only the visible page stays
      // mounted); disposing the player then still reports "stopped".
      if (!mounted) {
        sub.cancel();
        return;
      }
      if (state == ap.PlayerState.completed ||
          state == ap.PlayerState.stopped) {
        setState(() => _isInputPlaying = false);
        sub.cancel();
      }
    });
    await _inputAudioPlayer!.play(ap.DeviceFileSource(file.path));
  }

  Future<void> _stopInputSound() async {
    await _inputAudioPlayer?.stop();
    setState(() => _isInputPlaying = false);
  }

  Future<void> _playOutputSound() async {
    // Stop the other audio player if playing
    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = false;
    });

    await _outputAudioPlayer?.stop();
    setState(() {
      _isOutputPlaying = true;
    });
    _outputAudioPlayer ??= ap.AudioPlayer();

    File file;
    if (_outputAudioCacheText == _inputController.text &&
        _outputAudioCacheFile != null) {
      file = _outputAudioCacheFile!;
    } else {
      try {
        file = await _ttsService.synthesizeSpeech(
          text: _inputController.text,
          voice: "onyx",
          instructions: instructionForLang(_leftLanguage),
          langCode: _leftLanguage.code,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isOutputPlaying = false);
        showTtsError(context, e);
        return;
      }
      _outputAudioCacheText = _inputController.text;
      _outputAudioCacheFile = file;
    }

    late final StreamSubscription sub;
    sub = _outputAudioPlayer!.onPlayerStateChanged.listen((state) {
      // The page can be closed mid-playback (only the visible page stays
      // mounted); disposing the player then still reports "stopped".
      if (!mounted) {
        sub.cancel();
        return;
      }
      if (state == ap.PlayerState.completed ||
          state == ap.PlayerState.stopped) {
        setState(() => _isOutputPlaying = false);
        sub.cancel();
      }
    });
    await _outputAudioPlayer!.play(ap.DeviceFileSource(file.path));
  }

  Future<void> _stopOutputSound() async {
    await _outputAudioPlayer?.stop();
    setState(() => _isOutputPlaying = false);
  }

  Future<void> _playSoundWithOpenAI(
    String text,
    Language lang,
    String instructions,
    VoidCallback onStart,
    VoidCallback onDone,
  ) async {
    // Nothing to read (the edit panel was emptied): no read-aloud call.
    if (text.trim().isEmpty) {
      onDone();
      return;
    }
    try {
      _audioPlayer ??= ap.AudioPlayer();
      await _audioPlayer!.stop();

      final file = await _ttsService.synthesizeSpeech(
        text: text,
        voice: "onyx",
        instructions: instructions,
        langCode: lang.code,
      );
      if (!await file.exists() || (await file.length()) == 0) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("TTS failed: ${file.path}")));
        }
        setState(() => _isAudioPlaying = false);
        onDone();
        return;
      }

      late final StreamSubscription sub;
      sub = _audioPlayer!.onPlayerStateChanged.listen((state) {
        // The page can be closed mid-playback (only the visible page stays
        // mounted); disposing the player then still reports "stopped".
        if (!mounted) {
          sub.cancel();
          return;
        }
        if (state == ap.PlayerState.playing) {
          setState(() => _isAudioPlaying = true);
          onStart();
        }
        if (state == ap.PlayerState.completed) {
          setState(() => _isAudioPlaying = false);
          onDone();
          sub.cancel();
        }
        if (state == ap.PlayerState.stopped) {
          setState(() => _isAudioPlaying = false);
          onDone();
          sub.cancel();
        }
      });

      await _audioPlayer!.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      if (mounted) showTtsError(context, e);
      setState(() => _isAudioPlaying = false);
      onDone();
    }
  }

  Future<void> _autoPlayInputTTS() async {
    await _inputAudioPlayer?.stop();
    setState(() {
      _isInputPlaying = true;
      _isOutputPlaying = false;
      _isAudioLoadingInput = true;
    });
    await _playInputSound(); // handles file and plays
    setState(() {
      _isAudioLoadingInput = false;
      _isInputPlaying = false; // will also be set in the listener
    });
  }

  Future<void> _autoPlayOutputTTS() async {
    await _outputAudioPlayer?.stop();
    setState(() {
      _isOutputPlaying = true;
      _isInputPlaying = false;
      _isAudioLoadingOutput = true;
    });
    await _playOutputSound();
    setState(() {
      _isAudioLoadingOutput = false;
      _isOutputPlaying = false; // will also be set in the listener
    });
  }

  Future<void> autoTranslateOnLanguageChange({
    bool leftChanged = true,
    bool playTTS = true,
  }) async {
    setState(() {
      _isTranslating = true;
      if (leftChanged) {
        _isAudioLoadingOutput = true;
      } else {
        _isAudioLoadingInput = true;
      }
    });

    final String sourceText =
        leftChanged ? _translation : _inputController.text;
    final Language fromLang = leftChanged ? _rightLanguage : _leftLanguage;
    final Language toLang = leftChanged ? _leftLanguage : _rightLanguage;

    if (sourceText.trim().isEmpty) {
      setState(() {
        _isTranslating = false;
        _isAudioLoadingOutput = false;
        _isAudioLoadingInput = false;
      });
      return;
    }

    try {
      final result = await _gemini.translate(
        sourceText,
        fromLang.code,
        toLang.code,
      );
      unawaited(
        HistoryStore.save(
          input: sourceText,
          output: result,
          from: fromLang,
          to: toLang,
        ),
      );
      if (!mounted) return;
      setState(() {
        if (leftChanged) {
          _inputController.text = result;
        } else {
          _translation = result;
        }
      });
      if (playTTS) {
        if (leftChanged) {
          await _autoPlayOutputTTS();
        } else {
          await _autoPlayInputTTS();
        }
      }
    } catch (_) {
      // A failed translation used to leave the spinner spinning forever
      // (Markus's "spinner doesn't stop"). Clear it and show a friendly popup.
      if (mounted) showFriendlyError(context);
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _isAudioLoadingOutput = false;
          _isAudioLoadingInput = false;
        });
      }
    }
  }

  Future<void> showEditStackModal({
    required BuildContext context,
    required String initialText,
    required Language lang,
    required ValueChanged<String> onEdited,
    required ValueChanged<String> onTranscribed,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, a1, a2) {
        final keyboard = MediaQuery.of(ctx).viewInsets.bottom;
        return Center(
          child: SingleChildScrollView(
            // This makes the entire stack move above the keyboard!
            padding: EdgeInsets.only(bottom: keyboard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered, not full-screen
                RecordingModal(
                  lang: lang,
                  isTopPanel: true,
                  // pass controller
                  onTranscribed: (txt) {
                    Navigator.of(ctx).pop();
                    onTranscribed(txt);
                  },
                ),
                const SizedBox(height: 16),
                EditTextModal(
                  initialText: initialText,
                  onEdited: ({
                    required String edited,
                    required String translated,
                  }) {
                    // Update state for both panels!
                    setState(() {
                      _translation =
                          edited; // the text in the panel you just edited
                      _inputController.text =
                          translated; // the translation for the opposite panel
                    });
                  },
                  onLanguagesChanged:
                      (from, to) => _applyEditedLanguages(
                        leftPanel: lang == _leftLanguage,
                        from: from,
                        to: to,
                      ),
                  fromLang: lang, // this panel's language
                  toLang:
                      lang == _leftLanguage ? _rightLanguage : _leftLanguage,
                  gemini: _gemini,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Translates a finished voice recording and records it in History.
  Future<String> translateFinal(String input, Language from, Language to) async {
    // Single pass — the previous HU branch translated twice, which doubled
    // latency and re-translated an already-translated result.
    final result = await _gemini.translate(input, from.code, to.code);
    unawaited(
      HistoryStore.save(input: input, output: result, from: from, to: to),
    );
    return result;
  }

  bool _isTopRecording = false;
  bool _isBottomRecording = false;

  Future<void> _openRecordingCustom({
    required Language from,
    required Language to,
    required bool isTopPanel,
  }) async {
    debugPrint('Opening recording modal - top? $isTopPanel');

    // Interrupt any audio currently playing so it doesn't keep talking over
    // the new recording (Markus, 2026-07-12: tapping record should pause all
    // playing audio immediately, same as the edit panel already does).
    _inputAudioPlayer?.stop();
    _outputAudioPlayer?.stop();
    _audioPlayer?.stop();

    setState(() {
      _isInputPlaying = false;
      _isOutputPlaying = false;
      _isAudioPlaying = false;
      if (isTopPanel) {
        _isTopRecording = true;
      } else {
        _isBottomRecording = true;
      }
    });
  }

  late final FlutterTts _flutterTts;
  // 3) State fields for left/right languages
  Language _leftLanguage = Language.hungarian;
  Language _rightLanguage = Language.german;

  // Public so the nav bar (main.dart, via a GlobalKey) can reactively enable
  // the Tutor bulb only while Hungarian text is actually present on this
  // page. Recomputed once per build() rather than at every individual
  // mutation site, since text/language state changes in many places here.
  final ValueNotifier<bool> hasHungarianText = ValueNotifier(false);

  void _updateHasHungarianText() {
    final hungarianText =
        _leftLanguage == Language.hungarian
            ? _inputController.text
            : _rightLanguage == Language.hungarian
            ? _translation
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

  // 4) Helper to pick the next language, skipping the one on the other side.
  // The third slot is whatever the user picked in Settings (defaults to
  // English), not English unconditionally.
  Language _nextLanguage(Language current, Language other) {
    final all = [
      Language.hungarian,
      Language.german,
      ThirdLanguagePref.current,
    ];
    var idx = all.indexOf(current);
    var next = all[(idx + 1) % all.length];
    if (next == other) next = all[(idx + 2) % all.length];
    return next;
  }

  /// The edit panel's language check found the text in another language
  /// and the user chose to use it: [from]/[to] is the pair it translated
  /// with. [leftPanel] says which panel was edited (its language is [from]).
  void _applyEditedLanguages({
    required bool leftPanel,
    required Language from,
    required Language to,
  }) {
    setState(() {
      if (leftPanel) {
        _leftLanguage = from;
        _rightLanguage = to;
      } else {
        _rightLanguage = from;
        _leftLanguage = to;
      }
    });
  }

  void showEditTextModal({
    required BuildContext context,
    required String initialText,
    required Language fromLang,
    required Language toLang,
    required GeminiTranslator gemini,
    required OnEditAndTranslate onEdited, // <- Use your typedef!
    OnLanguagesChanged? onLanguagesChanged,
  }) {
    // Interrupt any audio currently playing before the user starts editing,
    // so the TTS voice doesn't keep talking over the correction.
    _inputAudioPlayer?.stop();
    _outputAudioPlayer?.stop();
    _audioPlayer?.stop();
    setState(() {
      _isInputPlaying = false;
      _isOutputPlaying = false;
      _isAudioPlaying = false;
    });

    // EditTextModal owns its controller, so the sheet builder re-running on
    // keyboard toggles never resets the text (Markus: text disappears after
    // record + keyboard) and it is disposed only after the sheet is gone.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: EditTextModal(
            initialText: initialText,
            onEdited: onEdited, // Pass it directly
            onLanguagesChanged: onLanguagesChanged,
            fromLang: fromLang,
            toLang: toLang,
            gemini: gemini,
          ),
        );
      },
    );
  }

  final GlobalKey inputKey = GlobalKey();
  final GlobalKey outputKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ThirdLanguagePref.notifier.addListener(_onThirdLanguageChanged);
    _flutterTts = FlutterTts();
    _flutterTts
      ..setSpeechRate(0.5)
      ..setVolume(1.0)
      ..setPitch(1.0);

    // Restore whatever was on screen before this page's State got torn down
    // by a tab switch (see conversation_state.dart).
    _inputController.text = ConversationState.inputText;
    _translation = ConversationState.translation;
    if (ConversationState.leftLang != null) {
      _leftLanguage = ConversationState.leftLang!;
    }
    if (ConversationState.rightLang != null) {
      _rightLanguage = ConversationState.rightLang!;
    }
  }

  void _copyText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showCopiedToast(context, AppLocalizations.of(context)!.copiedToClipboard);
  }

  // Document icon: carries both cards' current text into Document mode
  // (top/dark card -> Document's input box, bottom/bright card -> Document's
  // output box) and switches to that tab.
  void _openInDocumentMode() {
    DocumentTranslationState.inputText = _translation;
    DocumentTranslationState.translatedText = _inputController.text;
    // Carry the languages so the document panel speaks each side in the right
    // voice. inputText is the right-language text, translatedText the left.
    DocumentTranslationState.leftLang = _leftLanguage;
    DocumentTranslationState.rightLang = _rightLanguage;
    widget.onOpenDocument?.call();
  }

  // Tutor: opens the grammar/vocabulary explanation modal for whichever card
  // actually holds the Hungarian text (not always the top card, that was a
  // bug — the Tutor was explaining German text whenever German happened to
  // be on top). Public so the nav bar's bulb button (main.dart) can trigger
  // it via a GlobalKey, now that the bulb no longer lives on the card itself.
  void openTutor() {
    final hungarianText =
        _leftLanguage == Language.hungarian
            ? _inputController.text.trim()
            : _rightLanguage == Language.hungarian
            ? _translation.trim()
            : '';
    final other =
        _leftLanguage == Language.hungarian ? _rightLanguage : _leftLanguage;
    // The new Tutor page (Markus, 2026-10-09) replaces the old modal.
    TutorLauncher.open(hungarianText, otherLangCode: other.code);
  }

  @override
  void dispose() {
    ThirdLanguagePref.notifier.removeListener(_onThirdLanguageChanged);
    ConversationState.inputText = _inputController.text;
    ConversationState.translation = _translation;
    ConversationState.leftLang = _leftLanguage;
    ConversationState.rightLang = _rightLanguage;

    _audioPlayer?.dispose();

    _inputAudioPlayer?.dispose();
    _outputAudioPlayer?.dispose();
    hasHungarianText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateHasHungarianText();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Symmetric vertical padding so the two cards mirror each other
        // exactly. halfHeight is measured from the *padded* area, so the top
        // and bottom cards come out identical in height and margin. Kept small
        // so the cards fill toward the menu with little wasted space.
        final double vPad = 3.0;
        final halfHeight = (constraints.maxHeight - 2 * vPad) / 2;
        // Flag icons and label text got the 59% bump (2026-07-14), but the
        // swap button itself reverted back to its original size on request
        // (Markus, 2026-07-14: "revert switch icon to its original size,
        // just switch icon").
        final switchSize = 70.0;
        final switchHalf = switchSize / 2;
        // The two cards are mirror images about the centre line: equal heights,
        // equal margins. They meet along a stepped seam through the switch
        // button (flat on each side, the step hidden behind it).
        final switchRowTop = halfHeight - switchHalf;

        return Container(
          padding: EdgeInsets.symmetric(vertical: vPad),
          child: Stack(
            children: [
              // --- UPDATED: Top (input) card ---
              Positioned(
                top: 0,
                // Was 16 — narrower than it needed to be, leaving the card
                // visibly smaller than the rest of the screen width (Markus,
                // 2026-07-14: side-by-side mockup showing the whole card
                // bigger). Down to the shared scale's sm tier.
                left: Spacing.sm,
                right: Spacing.sm,
                height: halfHeight + switchHalf, // down to the bottom of the switch
                child: TranslationCard(
                  inverted: true,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  edgeClipper: _SeamClipper(
                    switchSize: switchSize,
                    keepTop: true,
                  ),
                  text: _translation,
                  siblingText: _inputController.text,
                  fromLang: _rightLanguage,
                  toLang: _leftLanguage,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingInput,
                  isAudioPlaying: _isInputPlaying,
                  isRecording: _isTopRecording,
                  onExplain: openTutor,
                  onCopy: () => _copyText(_translation),
                  onPlay: _playInputSound,
                  onStop: _stopInputSound,
                  onMicTap:
                      () => _openRecordingCustom(
                        from: _rightLanguage,
                        to: _leftLanguage,
                        isTopPanel: true,
                      ),
                  onMicCancel: () => setState(() => _isTopRecording = false),
                  onEdit:
                      () => showEditTextModal(
                        context: context,
                        initialText: _inputController.text,
                        fromLang: _leftLanguage,
                        toLang: _rightLanguage,
                        gemini: _gemini,
                        onEdited: ({
                          required String edited,
                          required String translated,
                        }) {
                          setState(() {
                            _inputController.text =
                                edited; // The panel you edited
                            _translation =
                                translated; // The opposite panel auto-translate
                          });
                          _playSoundWithOpenAI(
                            _translation,
                            _rightLanguage,
                            instructionForLang(_rightLanguage),
                            () {}, // Don't reveal (already visible)
                            () {
                              if (mounted) {
                                setState(() => _isTranslating = false);
                              }
                            },
                          );
                        },
                        onLanguagesChanged:
                            (from, to) => _applyEditedLanguages(
                              leftPanel: true,
                              from: from,
                              to: to,
                            ),
                      ),
                ),
              ),

              // --- UPDATED: Bottom (output) card ---
              Positioned(
                top: halfHeight - switchHalf, // up to the top of the switch
                left: Spacing.sm,
                right: Spacing.sm,
                bottom: 0, // reach the bottom edge of the screen
                child: TranslationCard(
                  inverted: false,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  edgeClipper: _SeamClipper(
                    switchSize: switchSize,
                    keepTop: false,
                  ),
                  text: _inputController.text,
                  siblingText: _translation,
                  fromLang: _leftLanguage,
                  toLang: _rightLanguage,
                  isBusy: _isTranslating,
                  isAudioLoading: _isAudioLoadingOutput,
                  isAudioPlaying: _isOutputPlaying,
                  isRecording: _isBottomRecording,
                  onCopy: () => _copyText(_inputController.text),
                  onPlay: _playOutputSound,
                  onStop: _stopOutputSound,
                  onOpenDocument: _openInDocumentMode,
                  onMicTap:
                      () => _openRecordingCustom(
                        from: _leftLanguage,
                        to: _rightLanguage,
                        isTopPanel: false,
                      ),
                  onMicCancel: () => setState(() => _isBottomRecording = false),
                  onEdit:
                      () => showEditTextModal(
                        context: context,
                        initialText: _inputController.text,
                        fromLang: _leftLanguage,
                        toLang: _rightLanguage,
                        gemini: _gemini,
                        onEdited: ({
                          required String edited,
                          required String translated,
                        }) {
                          setState(() {
                            _inputController.text =
                                edited; // The panel you edited
                            _translation =
                                translated; // The opposite panel auto-translate
                          });
                          _playSoundWithOpenAI(
                            _translation,
                            _rightLanguage,
                            instructionForLang(_rightLanguage),
                            () {}, // Don't reveal (already visible)
                            () {
                              if (mounted) {
                                setState(() => _isTranslating = false);
                              }
                            },
                          );
                        },
                        onLanguagesChanged:
                            (from, to) => _applyEditedLanguages(
                              leftPanel: true,
                              from: from,
                              to: to,
                            ),
                      ),
                ),
              ),

              // --- NEW: Restyled Language Switcher ---
              Positioned(
                top: switchRowTop,
                left: 26,
                right: 26,
                child: SizedBox(
                  height: switchSize,
                  child: Stack(
                    children: [
                      // Left language toggle (dark background)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _leftLanguage = _nextLanguage(
                                _leftLanguage,
                                _rightLanguage,
                              );
                            });
                            autoTranslateOnLanguageChange(leftChanged: true);
                          },
                          // No pill: EN sits on the white card, so a
                          // black-outlined label + black-bordered flag.
                          // Flag/text bumped up (Markus, 2026-07-14): first
                          // to 48/35, then dialed back to 42/30 (still too
                          // big at 48/35).
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              borderedFlag(
                                _leftLanguage,
                                whiteBorder: false,
                                size: 42,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _leftLanguage.label,
                                style: GoogleFonts.roboto(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Switch button
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            await _inputAudioPlayer?.stop();
                            await _outputAudioPlayer?.stop();
                            await _audioPlayer?.stop();
                            setState(() {
                              _isInputPlaying = false;
                              _isOutputPlaying = false;
                              final tmpLang = _leftLanguage;
                              _leftLanguage = _rightLanguage;
                              _rightLanguage = tmpLang;
                              final tmpText = _inputController.text;
                              _inputController.text = _translation;
                              _translation = tmpText;
                            });
                            autoTranslateOnLanguageChange(
                              leftChanged: true,
                              playTTS: false,
                            );
                            autoTranslateOnLanguageChange(
                              leftChanged: false,
                              playTTS: false,
                            );
                          },
                          child: Container(
                            width: switchSize,
                            height: switchSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/png24/black/b_change_round.png',
                                width: switchSize * 0.6,
                                height: switchSize * 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Right language toggle (white background)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _rightLanguage = _nextLanguage(
                                _rightLanguage,
                                _leftLanguage,
                              );
                            });
                            autoTranslateOnLanguageChange(leftChanged: false);
                          },
                          // HU pill sits on the inverted (top) card, so it is
                          // rotated 180° to read right-side-up for that speaker.
                          child: RotatedBox(
                            quarterTurns: 2,
                            // No pill: HU sits on the black card, so a
                            // white-outlined label + white-bordered flag.
                            // Flag first in code so that, once flipped 180°,
                            // the Hungarian reader sees the flag first (like DE).
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                borderedFlag(
                                  _rightLanguage,
                                  whiteBorder: true,
                                  size: 42,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _rightLanguage.label,
                                  style: GoogleFonts.roboto(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // === INLINE RECORDING PANELS (Non-modal) ===
              if (_isTopRecording)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: RecordingModal(
                        lang: _rightLanguage,
                        isTopPanel: true,
                        onTranscribed: (txt) async {
                          setState(() => _isTopRecording = false);
                          if (txt.trim().isEmpty) return;
                          if (!await ensureWiuBalance(context)) return;
                          setState(() {
                            _translation = txt;
                            _isTranslating = true;
                          });
                          try {
                            final result = await translateFinal(
                              txt,
                              _rightLanguage,
                              _leftLanguage,
                            );
                            if (!mounted) return;
                            setState(() {
                              _inputController.text = result;
                              _isTranslating = false;
                            });
                            // Auto-play the translation (parallel, non-blocking).
                            _playOutputSound();
                          } catch (_) {
                            if (mounted) {
                              setState(() => _isTranslating = false);
                              if (context.mounted) showFriendlyError(context);
                            }
                          }
                        },
                        onEditRequested: (txt) {
                          setState(() => _isTopRecording = false);
                          if (txt.trim().isEmpty) return;
                          showEditTextModal(
                            context: context,
                            initialText: txt,
                            fromLang: _rightLanguage,
                            toLang: _leftLanguage,
                            gemini: _gemini,
                            onEdited: ({
                              required String edited,
                              required String translated,
                            }) {
                              setState(() {
                                _translation = edited;
                                _inputController.text = translated;
                              });
                              _playOutputSound();
                            },
                            onLanguagesChanged:
                                (from, to) => _applyEditedLanguages(
                                  leftPanel: false,
                                  from: from,
                                  to: to,
                                ),
                          );
                        },
                        onCancel: () => setState(() => _isTopRecording = false),
                      ),
                    ),
                  ),
                ),

              if (_isBottomRecording)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: RecordingModal(
                        lang: _leftLanguage,
                        isTopPanel: false,
                        onTranscribed: (txt) async {
                          setState(() => _isBottomRecording = false);
                          if (txt.trim().isEmpty) return;
                          if (!await ensureWiuBalance(context)) return;
                          setState(() {
                            _inputController.text = txt;
                            _isTranslating = true;
                          });
                          try {
                            final result = await translateFinal(
                              txt,
                              _leftLanguage,
                              _rightLanguage,
                            );
                            if (!mounted) return;
                            setState(() {
                              _translation = result;
                              _isTranslating = false;
                            });
                            // Auto-play the translation (parallel, non-blocking).
                            _playInputSound();
                          } catch (_) {
                            if (mounted) {
                              setState(() => _isTranslating = false);
                              if (context.mounted) showFriendlyError(context);
                            }
                          }
                        },
                        onEditRequested: (txt) {
                          setState(() => _isBottomRecording = false);
                          if (txt.trim().isEmpty) return;
                          showEditTextModal(
                            context: context,
                            initialText: txt,
                            fromLang: _leftLanguage,
                            toLang: _rightLanguage,
                            gemini: _gemini,
                            onEdited: ({
                              required String edited,
                              required String translated,
                            }) {
                              setState(() {
                                _inputController.text = edited;
                                _translation = translated;
                              });
                              _playInputSound();
                            },
                            onLanguagesChanged:
                                (from, to) => _applyEditedLanguages(
                                  leftPanel: true,
                                  from: from,
                                  to: to,
                                ),
                          );
                        },
                        onCancel:
                            () => setState(() => _isBottomRecording = false),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
