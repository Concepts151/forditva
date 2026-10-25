import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:forditva/services/gemini_speech_service.dart';
import 'package:forditva/services/history_store.dart';
import 'package:forditva/widgets/amp_waveform.dart';
import 'package:forditva/widgets/error_dialog.dart';
import 'package:forditva/utils/utils.dart';
import 'package:forditva/widgets/language_mismatch_dialog.dart';
import 'package:forditva/widgets/mic_permission.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../models/language_enum.dart';

typedef OnEditAndTranslate =
    void Function({required String edited, required String translated});

/// Called before [OnEditAndTranslate] when the user accepted the shared
/// language-mismatch panel's suggestion, with the language pair that was
/// actually used, so the page can update its flags to match.
typedef OnLanguagesChanged = void Function(Language from, Language to);

class EditTextModal extends StatefulWidget {
  // The modal owns its TextEditingController (created from this, disposed in
  // State.dispose). Callers used to create it and dispose it in
  // showModalBottomSheet().whenComplete, which fires at pop() while the
  // TextField is still mounted for the exit animation; that crashed the
  // whole Navigator ('_dependents.isEmpty' red screen) after every edit.
  final String initialText;
  final OnLanguagesChanged? onLanguagesChanged;
  final Language fromLang;
  final Language toLang;
  final GeminiTranslator gemini;
  final OnEditAndTranslate onEdited;
  // Starts recording immediately once the modal opens — used when the caller
  // opened this modal specifically by tapping a microphone icon rather than
  // an edit/pencil icon (Markus, 2026-07-11: tapping mic on the Document page
  // should switch to this exact panel AND start recording).
  final bool autoStartRecording;
  // Where to put the cursor when the panel opens; null = end of the text.
  // Set when the user opened the panel by tapping into the text, so a
  // dictated sentence lands where they tapped (Markus, 2026-10-09).
  final int? initialCursorOffset;

  const EditTextModal({
    super.key,
    required this.initialText,
    required this.onEdited,
    this.onLanguagesChanged,
    required this.fromLang,
    required this.toLang,
    required this.gemini,
    this.autoStartRecording = false,
    this.initialCursorOffset,
  });

  @override
  State<EditTextModal> createState() => _EditTextModalState();
}

class _EditTextModalState extends State<EditTextModal> {
  // Height of the waveform band shown above the buttons while recording
  // (AmpWaveform bars are at most 36px tall).
  static const double _waveBandHeight = 44;

  // Survives the sheet builder re-running on keyboard toggles, so typed or
  // recorded text is never reset to initialText.
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  late final AudioRecorder _audioRecorder;

  bool _loading = false;
  bool _isRecording = false;
  String? _audioPath;
  // Waveform is driven by the single recorder's amplitude stream (0..1),
  // avoiding a second microphone recorder that would starve it of audio.
  final List<double> _levels = [];
  StreamSubscription<Amplitude>? _ampSub;
  final _speech = GeminiSpeechService();
  bool _isSttLoading = false;
  // Whether the mic level ever reached speech in this recording. Silence is
  // never sent to Gemini (see GeminiSpeechService.voiceLevel).
  bool _heardSpeech = false;
  // Stops the recording at GeminiSpeechService.maxDuration.
  Timer? _limitTimer;
  // The stop in progress, so the time limit and a tap on stop or confirm
  // at the same moment share one transcription instead of running two.
  Future<void>? _stopping;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    // Drive the waveform from the same recorder's amplitude (dBFS ~ -45..0),
    // so no second microphone recorder is needed. Subscribed once for the
    // modal's lifetime: record 5.x returns the same single-subscription
    // stream on every onAmplitudeChanged() call, so re-listening on each mic
    // tap threw "Stream has already been listened to" on the second
    // recording. The recorder only emits while recording.
    _ampSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((amp) {
          if (!mounted || !_isRecording) return;
          final norm = GeminiSpeechService.level(amp.current);
          if (norm >= GeminiSpeechService.voiceLevel) _heardSpeech = true;
          setState(() {
            _levels.add(norm);
            if (_levels.length > 60) _levels.removeAt(0);
          });
        });

    // Use addPostFrameCallback to set cursor after the initial build and focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure the widget is still in the tree
        final offset = widget.initialCursorOffset;
        if (offset != null) {
          _controller.selection = TextSelection.collapsed(
            offset: offset.clamp(0, _controller.text.length),
          );
        } else {
          _moveCursorToEnd();
        }
        if (widget.autoStartRecording) _onMicTap();
      }
    });
  }

  void _moveCursorToEnd() {
    // Only update selection if the text is not empty and the current selection is not already at the end.
    // This helps prevent unnecessary rebuilds and potential cursor jumpiness.
    final text = _controller.text;
    if (text.isNotEmpty) {
      final currentSelection = _controller.selection;
      if (currentSelection.baseOffset != text.length ||
          currentSelection.extentOffset != text.length) {
        _controller.selection = TextSelection.collapsed(
          offset: text.length,
        );
      }
    }
  }

  /// Inserts [text] wherever the user last placed the cursor, instead of
  /// always appending to the end (Markus, 2026-07-14: paste/recorded
  /// transcript should land at the cursor position, not the end of the
  /// sentence). Falls back to appending at the end if the selection is
  /// somehow invalid.
  void _insertAtCursor(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _controller.text;
    final selection = _controller.selection;
    final offset =
        selection.isValid ? selection.start.clamp(0, current.length) : current.length;

    final before = current.substring(0, offset);
    final after = current.substring(offset);
    final needsSpaceBefore =
        before.isNotEmpty && !before.endsWith(' ') && !before.endsWith('\n');
    final needsSpaceAfter =
        after.isNotEmpty && !after.startsWith(' ') && !after.startsWith('\n');
    final insertion =
        '${needsSpaceBefore ? ' ' : ''}$trimmed${needsSpaceAfter ? ' ' : ''}';

    _controller.value = TextEditingValue(
      text: before + insertion + after,
      selection: TextSelection.collapsed(offset: before.length + insertion.length),
    );
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _limitTimer?.cancel();
    _audioRecorder.dispose(); // Dispose of the audio recorder
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onMicTap() async {
    if (!await ensureMicPermission(context, _audioRecorder)) return;
    setState(() {
      _isRecording = true;
      _isSttLoading = false;
      _heardSpeech = false;
      _levels.clear();
    });
    final dir = await getTemporaryDirectory();
    _audioPath =
        '${dir.path}/edit_rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _audioPath!,
    );
    _limitTimer?.cancel();
    _limitTimer = Timer(GeminiSpeechService.maxDuration, () {
      if (_isRecording) _onStopTap();
    });
  }

  Future<void> _onStopTap() =>
      _stopping ??= _stopAndTranscribe().whenComplete(() => _stopping = null);

  Future<void> _stopAndTranscribe() async {
    _limitTimer?.cancel();
    setState(() => _isSttLoading = true);
    await _audioRecorder.stop(); // stops the actual file recording

    final path = _audioPath;
    if (path == null || !File(path).existsSync()) {
      setState(() {
        _isRecording = false;
        _isSttLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.recordingFailed),
          ),
        );
      }
      return;
    }

    // The language is passed to Gemini as such; before, only HU/DE were
    // mapped, so a French or Spanish dictation was recognized as English.
    var transcript = '';
    try {
      if (_heardSpeech) {
        transcript = await _speech.transcribe(File(path), widget.fromLang);
      }
    } catch (e) {
      debugPrint('Voice input failed: $e');
    } finally {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isSttLoading = false;
    });
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.couldNotTranscribe),
        ),
      );
      return;
    }
    // Lands at wherever the cursor was left, not always the end.
    _insertAtCursor(transcript);
    setState(() {}); // Refresh font size, etc.
  }

  /// Trash: empty the whole text field (Markus: "throw everything to the
  /// garbage tin"). The red X still cancels/closes the panel.
  void _clearText() {
    _controller.clear();
    setState(() {});
  }

  /// Paste: inserts clipboard text at the cursor position.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text ?? '';
    if (pasted.trim().isEmpty) return;
    _insertAtCursor(pasted);
    setState(() {});
  }

  /// Compact icon button for the control bar (tight padding so all controls
  /// fit on one row without overlapping).
  Widget _iconBtn(String asset, double size, VoidCallback? onTap) {
    return IconButton(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      constraints: const BoxConstraints(),
      icon: Image.asset(asset, width: size, height: size),
      onPressed: onTap,
    );
  }

  /// Stop recording and discard the audio without transcribing (the X shown
  /// while recording).
  Future<void> _discardRecording() async {
    _limitTimer?.cancel();
    await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isSttLoading = false;
        _levels.clear();
      });
    }
  }

  Future<void> _onCheckPressed() async {
    // Tapping confirm while a sub-recording is still running used to just
    // discard it and close the panel. Treat confirm as "done recording"
    // too: stop and append the transcript first, then proceed.
    if (_isRecording) {
      await _onStopTap();
    }
    final inputText = _controller.text.trim();
    // Everything deleted: clear both panels without a language check,
    // translation or history entry.
    if (inputText.isEmpty) {
      widget.onEdited(edited: '', translated: '');
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _loading = true);
    var from = widget.fromLang;
    var to = widget.toLang;
    final detected = await detectSupportedLanguageCode(
      inputText,
      widget.gemini,
    );
    if (detected != null && detected != from.code) {
      setState(() => _loading = false);
      if (!mounted) return;
      final useDetected = await showLanguageMismatchDialog(
        context,
        selectedCode: from.code,
        detectedCode: detected,
      );
      // Cancel keeps the panel open with the text, so it can be fixed.
      if (!useDetected || !mounted) return;
      final newFrom = Language.values.firstWhere((l) => l.code == detected);
      // Text written in the target language: swap the pair.
      if (newFrom == to) to = from;
      from = newFrom;
      setState(() => _loading = true);
    }
    final String translated;
    try {
      translated = await widget.gemini.translate(
        inputText,
        from.code,
        to.code,
      );
    } catch (e) {
      // No connection, or an answer the Firebase SDK cannot read (an empty
      // candidate throws "Unhandled format for Content"). Keep the panel and
      // its text open instead of spinning forever.
      debugPrint('Edit panel translation failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      await showFriendlyError(context);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(
      HistoryStore.save(
        input: inputText,
        output: translated,
        from: from,
        to: to,
      ),
    );
    if (from != widget.fromLang || to != widget.toLang) {
      widget.onLanguagesChanged?.call(from, to);
    }
    widget.onEdited(edited: inputText, translated: translated);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // Size against the space actually left above the keyboard, not the full
    // screen height, so the card never overlaps it once the keyboard is up.
    final availableHeight = MediaQuery.of(context).size.height - keyboardHeight;
    // Fill the space above the keyboard, minus the 25px top offset below and
    // a 20px breathing gap at the bottom — was leaving roughly half the
    // available height as dead grey space above the keyboard.
    final modalHeight = availableHeight - 25 - 20;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          // Push the whole card up above the keyboard as it rises.
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 25),
            child: Stack(
              children: [
                // White modal — inset from the screen edges so it reads as a
                // centered card over the dimmed conversation, not full-screen.
                Container(
                  width: width - 32,
                  height: modalHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Text input
                      Padding(
                        // Leaves room for the waveform band while recording.
                        padding: EdgeInsets.fromLTRB(
                          18,
                          18,
                          18,
                          _isRecording ? 70 + _waveBandHeight : 70,
                        ),
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          // Fixed font size that never shrinks; the field fills
                          // the card and scrolls when the text gets long, so no
                          // text is hidden when the keyboard is toggled (Markus).
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: GoogleFonts.robotoCondensed(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: AppLocalizations.of(context)!.editTextHint,
                            isDense: true,
                          ),
                        ),
                      ),
                      // Full-width waveform band above the button row while
                      // recording; squeezed into the row it only had room for
                      // a bar or two (Markus, 2026-10-09).
                      if (_isRecording)
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 66,
                          height: _waveBandHeight,
                          child: AmpWaveform(levels: _levels),
                        ),
                      // All edit controls on ONE row so nothing overlaps:
                      // cancel, clear, paste, mic (or discard/stop while
                      // recording), confirm.
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 10,
                        child: Row(
                          children: [
                            _iconBtn(
                              'assets/images/close_red.png',
                              48,
                              _loading
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                            ),
                            _iconBtn(
                              'assets/png24/black/b_garbage.png',
                              30,
                              _loading ? null : _clearText,
                            ),
                            _iconBtn(
                              'assets/png24/black/b_paste.png',
                              30,
                              _loading ? null : _pasteFromClipboard,
                            ),
                            // Middle fills all remaining width: mic centred
                            // when idle; X + tick centred when recording.
                            Expanded(
                              child:
                                  _isSttLoading
                                      // The app's grid loader, as on the
                                      // Text and Image pages.
                                      ? const Center(child: GifLoader(size: 40))
                                      : _isRecording
                                      ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _iconBtn(
                                            'assets/png24/black/b_close.png',
                                            30,
                                            _discardRecording,
                                          ),
                                          _iconBtn(
                                            'assets/png24/black/b_check.png',
                                            30,
                                            _onStopTap,
                                          ),
                                        ],
                                      )
                                      : Center(
                                        child: _iconBtn(
                                          'assets/images/b_microphone.png',
                                          30,
                                          _onMicTap,
                                        ),
                                      ),
                            ),
                            _iconBtn(
                              'assets/images/check_green.png',
                              48,
                              _loading ? null : _onCheckPressed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white60,
                      child: const Center(child: GifLoader(size: 80)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
