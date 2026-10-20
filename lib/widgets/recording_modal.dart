import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../models/language_enum.dart';
import '../services/gemini_speech_service.dart';

/// Central recording panel shown when the user taps the mic on a
/// conversation card.
///
/// Behaviour (per spec):
/// - The app records the audio itself; the waveform reacts to the real
///   microphone level (greyscale bars). On finish, Gemini transcribes it
///   with punctuation ([GeminiSpeechService]).
/// - By default, 1.5 seconds of silence after the last speech
///   auto-finalizes the recording and hands it off for translation.
/// - The infinity button disables that auto-finalize, so the user can keep
///   talking through longer pauses; only a manual action ends the session.
/// - Trash cancels and discards everything, no translation.
/// - Pencil stops the recording and hands the transcript to the text editor
///   (via [onEditRequested]) instead of translating immediately.
/// - Checkmark manually finalizes now and translates, same as the automatic
///   1.5s path.
///
/// Until 2026-10-20 this used the phone's built-in recognizer, with Google
/// Cloud STT as a fallback for phones without the language. Android played
/// its start sound every time the recognizer restarted after a pause
/// (Markus, 2026-10-12: the "pling"), and it returned no punctuation.
class RecordingModal extends StatefulWidget {
  final Language lang;
  final Function(String) onTranscribed;
  final bool isTopPanel;
  final Function(String)? onEditRequested;
  final VoidCallback? onCancel;

  const RecordingModal({
    super.key,
    required this.lang,
    required this.onTranscribed,
    required this.isTopPanel,
    this.onEditRequested,
    this.onCancel,
  });

  @override
  State<RecordingModal> createState() => _RecordingModalState();
}

class _RecordingModalState extends State<RecordingModal> {
  static const _silenceTimeout = Duration(milliseconds: 1500);
  // Rolling window of recent mic levels driving the waveform bars.
  static const int _levelWindow = 24;

  bool _isRecording = false;
  bool _isFinishing = false;
  // Once the user taps OK/trash/edit the panel hides immediately (Markus: it
  // must not stay open while the transcript/translation is still computing);
  // the recording still finalizes in the background.
  bool _dismissed = false;
  bool _continuousMode = false; // infinity toggle
  // Whether the mic level ever reached speech in this recording. Silence is
  // never sent to Gemini (see GeminiSpeechService.voiceLevel).
  bool _heardSpeech = false;
  bool _isTranscribing = false;
  Timer? _silenceTimer;
  Timer? _limitTimer;
  final List<double> _levels = [];
  // Current mic "energy" (0..1). A ticker scrolls it into _levels.
  double _energy = 0.0;
  Timer? _waveTimer;

  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _ampSub;
  String? _path;

  final _speech = GeminiSpeechService();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _waveTimer?.cancel();
    _limitTimer?.cancel();
    _ampSub?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _isRecording = true;
      _heardSpeech = false;
      _levels.clear();
    });

    // Steady ticker that scrolls the current energy into the waveform and lets
    // it decay, so the bars keep moving while speaking and settle in silence.
    _waveTimer ??= Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        _levels.add(_energy);
        if (_levels.length > _levelWindow) _levels.removeAt(0);
        _energy *= 0.72;
      });
    });

    final recorder = _recorder ??= AudioRecorder();
    // record 5.x hands out one single-subscription amplitude stream per
    // recorder, so subscribe once and reuse it across retries.
    _ampSub ??= recorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen(_onAmplitude);

    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/conv_rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _path!,
      );
    } catch (_) {
      _showCouldNotTranscribe();
      widget.onCancel?.call();
      return;
    }
    _limitTimer?.cancel();
    _limitTimer = Timer(GeminiSpeechService.maxDuration, _finishAndTranslate);
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted || !_isRecording || _isFinishing) return;
    final e = GeminiSpeechService.level(amp.current);
    if (e > _energy) _energy = e;
    if (e >= GeminiSpeechService.voiceLevel) {
      _heardSpeech = true;
      // 1.5s after the last speech, finish automatically (not in infinity
      // mode).
      if (!_continuousMode) {
        _silenceTimer?.cancel();
        _silenceTimer = Timer(_silenceTimeout, _finishAndTranslate);
      }
    }
  }

  /// Stops the recording and returns its transcript ('' when there was no
  /// speech or it failed).
  Future<String> _stopAndTranscribe() async {
    _limitTimer?.cancel();
    final path = await _recorder?.stop() ?? _path;
    if (path == null || !File(path).existsSync()) return '';
    try {
      if (!_heardSpeech) return '';
      return await _speech.transcribe(File(path), widget.lang);
    } catch (e) {
      debugPrint('Voice input failed: $e');
      return '';
    } finally {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  void _showCouldNotTranscribe() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.couldNotTranscribe)),
    );
  }

  void _toggleContinuous() {
    setState(() => _continuousMode = !_continuousMode);
    if (_continuousMode) _silenceTimer?.cancel();
  }

  /// Checkmark, or the automatic 1.5s-silence path: stop and translate now.
  Future<void> _finishAndTranslate() async {
    if (!_isRecording || _isFinishing) return;
    _isFinishing = true;
    _silenceTimer?.cancel();
    // The words only exist once Gemini answers (a few seconds), so keep the
    // panel up with a spinner instead of hiding it with no feedback.
    if (mounted) setState(() => _isTranscribing = true);
    _isRecording = false;
    final text = await _stopAndTranscribe();
    if (!mounted) return;
    setState(() => _isTranscribing = false);

    if (text.isEmpty) {
      // Nothing understandable was captured: ask the user to try again
      // instead of closing the panel with an empty result.
      _showCouldNotTranscribe();
      _isFinishing = false;
      _start();
      return;
    }
    setState(() => _dismissed = true);
    widget.onTranscribed(text);
  }

  /// Trash: cancel and discard, no translation.
  Future<void> _cancelAndDiscard() async {
    if (mounted) setState(() => _dismissed = true);
    _silenceTimer?.cancel();
    _limitTimer?.cancel();
    _isRecording = false;
    await _recorder?.cancel();
    widget.onCancel?.call();
  }

  /// Pencil: stop and hand the transcript to the text editor.
  Future<void> _editInstead() async {
    if (_isFinishing) return;
    _isFinishing = true;
    _silenceTimer?.cancel();
    if (mounted) setState(() => _isTranscribing = true);
    _isRecording = false;
    final text = await _stopAndTranscribe();
    if (!mounted) return;
    setState(() {
      _isTranscribing = false;
      _dismissed = true;
    });
    widget.onEditRequested?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    // Hidden the moment the user commits; the async work continues behind it.
    if (_dismissed) return const SizedBox.shrink();
    // Was a fixed 320px regardless of screen size (Markus, 2026-07-11: "does
    // it work on all mobile resolutions?"). Scales with the screen instead,
    // clamped so it stays usable on the narrowest phones and doesn't grow
    // oversized on large phones/tablets.
    final panelWidth = (MediaQuery.of(context).size.width * 0.85).clamp(
      280.0,
      380.0,
    );
    return Material(
      elevation: 24,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: panelWidth,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 50,
              child: Center(
                child:
                    _isTranscribing
                        ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : _LevelWaveform(levels: _levels),
              ),
            ),
            // No raw error codes shown in the panel (Markus): genuine failures
            // surface via a friendly dialog elsewhere, not as red text here.
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlButton(
                  assetPath: 'assets/images/record_trash.png',
                  onTap: _cancelAndDiscard,
                ),
                _ControlButton(
                  assetPath: 'assets/images/record_infinity.png',
                  active: _continuousMode,
                  onTap: _toggleContinuous,
                ),
                _ControlButton(
                  assetPath: 'assets/images/record_edit.png',
                  onTap: _editInstead,
                ),
                _ControlButton(
                  assetPath: 'assets/images/record_confirm.png',
                  onTap: _finishAndTranslate,
                  emphasized: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of grey vertical bars reacting to recent microphone sound levels.
class _LevelWaveform extends StatelessWidget {
  final List<double> levels;
  const _LevelWaveform({required this.levels});

  @override
  Widget build(BuildContext context) {
    const barCount = 20;
    // levels are already 0..1 energy values (see _RecordingModalState).
    double heightFor(double level) {
      return 6 + level.clamp(0.0, 1.0) * 34;
    }

    final bars = List<double>.generate(barCount, (i) {
      final idx = levels.length - barCount + i;
      return idx >= 0 ? heightFor(levels[idx]) : 6.0;
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          bars
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    height: h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

/// One bordered square control button (trash / infinity / pencil / confirm),
/// using Markus's dedicated icon set for the recording panel. Matches the
/// reference screenshot: thin black-bordered squares, the confirm button
/// noticeably larger with a bolder border. The infinity toggle's active state
/// is shown by filling the square black and tinting its icon white.
class _ControlButton extends StatelessWidget {
  final String assetPath;
  final bool active;
  final bool emphasized;
  final VoidCallback onTap;

  const _ControlButton({
    required this.assetPath,
    this.active = false,
    this.emphasized = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = emphasized ? 58.0 : 50.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          border: Border.all(
            color: Colors.black,
            width: emphasized ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            width: boxSize * 0.55,
            height: boxSize * 0.55,
            color: active ? Colors.white : null,
            colorBlendMode: active ? BlendMode.srcIn : null,
          ),
        ),
      ),
    );
  }
}
