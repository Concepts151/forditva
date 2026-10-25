import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forditva/document/document_translation_page.dart'
    show LandscapeZoomModal;
import 'package:forditva/models/language_enum.dart';
import 'package:forditva/utils/utils.dart';
import 'package:google_fonts/google_fonts.dart';

const double _cardHorizontalPadding = 16.0;

// ─── Translation text font sizes ──────────────────────────────────────
// Four discrete tiers. The largest tier whose laid-out height fits the
// available panel wins. If even the smallest tier overflows, the text
// scrolls inside the card (same behaviour upside-down for the inverted card).
const double _fontSizeXL = 46.0;
const double _fontSizeL = 38.0;
const double _fontSizeM = 32.0;
const double _fontSizeS = 26.0;
const List<double> _fontSizeTiers = [
  _fontSizeXL,
  _fontSizeL,
  _fontSizeM,
  _fontSizeS,
];

// Roboto Condensed Medium — used for both rendering and measurement so the
// chosen tier matches what actually gets drawn.
TextStyle _translationTextStyle(double fontSize, Color color) =>
    GoogleFonts.robotoCondensed(
      color: color,
      fontSize: fontSize,
      height: 1.1,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.3,
    );

/// Picks the largest tier whose laid-out height fits [maxHeight].
/// Falls back to the smallest tier (the card then scrolls).
/// Largest tier whose laid-out height fits [maxHeight] for *every* text in
/// [texts]. Passing both cards' texts makes the two cards size to the same
/// tier (driven by the longer text), so they always match.
double _fitFontSize(List<String> texts, double maxWidth, double maxHeight) {
  for (final size in _fontSizeTiers) {
    var allFit = true;
    for (final t in texts) {
      if (t.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: t, style: _translationTextStyle(size, Colors.black)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      if (painter.height > maxHeight) {
        allFit = false;
        break;
      }
    }
    if (allFit) return size;
  }
  return _fontSizeTiers.last;
}

class TranslationCard extends StatelessWidget {
  /// dark/inverted = input card (top icons), bright = output card (bottom icons)
  final bool inverted;

  /// The text to display
  final String text;

  /// The other card's text. Used only for font sizing, so both cards pick the
  /// same tier (driven by the longer of the two) and stay matched.
  final String siblingText;

  final Language fromLang, toLang;
  final bool isBusy, isAudioLoading, isAudioPlaying, isRecording;

  /// Corner rounding for the card. Defaults to all corners; the conversation
  /// screen passes only the outer corners so the two cards meet flush where
  /// they overlap behind the switch button.
  final BorderRadius borderRadius;

  /// Optional diagonal/edge clip applied on top of [borderRadius]. The
  /// conversation screen uses this to give the two cards a slanted seam that
  /// runs through the switch button.
  final CustomClipper<Path>? edgeClipper;

  /// Document icon (bottom card only): copies both cards' text into Document
  /// mode and switches to it. Not wired directly here since it needs both
  /// cards' current text, which only the conversation page (textpage.dart)
  /// has; this just forwards the tap.
  final VoidCallback? onOpenDocument;

  final VoidCallback? onExplain,
      onCopy,
      onPlay,
      onStop,
      onEdit,
      onMicTap,
      onMicCancel;

  const TranslationCard({
    super.key,
    required this.inverted,
    required this.text,
    this.siblingText = '',
    required this.fromLang,
    required this.toLang,
    this.isBusy = false,
    this.isAudioLoading = false,
    this.isAudioPlaying = false,
    this.isRecording = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.edgeClipper,
    this.onOpenDocument,
    this.onExplain,
    this.onCopy,
    this.onPlay,
    this.onStop,
    this.onEdit,
    this.onMicTap,
    this.onMicCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bgImg =
        inverted ? 'assets/images/bg-dark.jpg' : 'assets/images/bg-bright.jpg';
    final txtColor = inverted ? Colors.white : Colors.black;

    // icon paths
    final expandIcon =
        inverted
            ? 'assets/png24/white/w_fullscreen.png'
            : 'assets/png24/black/b_fullscreen.png';
    final documentIcon = 'assets/png24/black/b_document.png';
    final speakerIcon =
        inverted
            ? 'assets/png24/white/w_speaker.png'
            : 'assets/png24/black/b_speaker.png';
    // Markus's pause icon (tap stops): the old w_stop.png square was
    // thinner and smaller than the icons beside it (Markus, 2026-10-25).
    final stopIcon =
        inverted
            ? 'assets/png24/white/w_pause.png'
            : 'assets/png24/black/b_pause.png';
    final micIcon =
        isRecording
            ? 'assets/images/stoprec.png'
            : 'assets/images/microphone-white-border.png';

    final screenWidth = MediaQuery.of(context).size.width;
    final double iconSize = (screenWidth * 0.085).clamp(24.0, 48.0);
    final Widget card = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // background
          Image.asset(bgImg, fit: BoxFit.cover),

          // ─── TEXT PANEL ───────────────────────────
          Positioned(
            top: 85.0,
            bottom: 85.0,
            left: _cardHorizontalPadding,
            right: _cardHorizontalPadding,
            child: RotatedBox(
              quarterTurns: inverted ? 2 : 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fontSize = _fitFontSize(
                    [text, siblingText],
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  // While translating, hide the previous (stale) text so only
                  // the spinner shows until the new result arrives.
                  final shownText = isBusy ? '' : text;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: onEdit,
                          child: Text(
                            shownText,
                            textAlign: TextAlign.center,
                            style: _translationTextStyle(fontSize, txtColor),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // busy overlay — shown while a translation is in flight so the
          // user gets feedback instead of staring at a blank/stale card.
          if (isBusy)
            Positioned.fill(
              child: ColoredBox(
                color: (inverted ? Colors.black : Colors.white).withValues(
                  alpha: 0.35,
                ),
                child: Center(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        inverted ? Colors.white : const Color(0xFF436F4D),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (inverted) ...[
            // ─── TOP RIGHT: expand (fullscreen) + speaker ──────────
            Positioned(
              top: 16,
              right: 20,
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        () => showDialog(
                          context: context,
                          builder: (_) => LandscapeZoomModal(text: text),
                        ),
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Image.asset(
                        expandIcon,
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap:
                        isAudioLoading
                            ? null
                            : isAudioPlaying
                            ? onStop
                            : onPlay,
                    child:
                        // The app's loader while the voice is generated;
                        // a long text takes seconds (Markus, 2026-10-25).
                        isAudioLoading
                            ? GifLoader(size: iconSize)
                            : isAudioPlaying
                            ? Image.asset(
                              stopIcon,
                              width: iconSize,
                              height: iconSize,
                            )
                            : Transform.rotate(
                              angle: math.pi,
                              child: Image.asset(
                                speakerIcon,
                                width: iconSize,
                                height: iconSize,
                              ),
                            ),
                  ),
                ],
              ),
            ),

            // ─── TOP CENTER: mic + flag ───────────
            if (onMicTap != null)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (isRecording) {
                        onMicCancel?.call();
                      } else {
                        onMicTap!();
                      }
                    },
                    child: RotatedBox(
                      quarterTurns: 2,
                      child: Container(
                        width: 60,
                        height: 60,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          image: DecorationImage(
                            image: AssetImage(
                              'assets/flags/${fromLang.label}_W.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Center(
                          child: Image.asset(
                            micIcon,
                            width: iconSize,
                            height: iconSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ] else ...[
            // ─── BOTTOM CENTER: mic + flag ─────────
            if (onMicTap != null)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (isRecording) {
                        onMicCancel?.call();
                      } else {
                        onMicTap!();
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        image: DecorationImage(
                          image: AssetImage(
                            'assets/flags/${fromLang.label}_B.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          micIcon,
                          width: iconSize,
                          height: iconSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ─── BOTTOM LEFT: edit + document (open in Document mode) ──────
            Positioned(
              bottom: 16,
              left: 20,
              child: Row(
                children: [
                  if (onEdit != null)
                    GestureDetector(
                      onTap: onEdit,
                      child: Image.asset(
                        'assets/png24/black/b_edit.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onOpenDocument,
                    child: Image.asset(
                      documentIcon,
                      width: iconSize,
                      height: iconSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (edgeClipper != null) {
      return ClipPath(clipper: edgeClipper, child: card);
    }
    return card;
  }
}
