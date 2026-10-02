import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:forditva/document/document_translation_page.dart'
    show LandscapeZoomModal;
import 'package:forditva/services/gemini_image_service.dart';
import 'package:forditva/widgets/wiu_gate.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:forditva/services/gemini_tts_service.dart';
import 'package:share_plus/share_plus.dart'; // your Gemini client
import 'package:forditva/utils/utils.dart';
import 'package:forditva/widgets/cropper.dart';
import 'package:forditva/services/document_conversion_service.dart';
import 'package:forditva/widgets/document_question_dialog.dart';
import 'package:forditva/widgets/pdf_page_selector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'services/third_language_pref.dart';
import 'spacing.dart';
import 'widgets/copied_toast.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

enum Language { hu, de, en, nl, fr, es, ru, it }

/// This page keeps its own local Language enum (hu/de/en/...) instead of
/// importing models/language_enum.dart, so the shared "third language"
/// preference is looked up by its two-letter code rather than by type.
Language _localThirdLang() {
  switch (ThirdLanguagePref.currentCode) {
    case 'NL':
      return Language.nl;
    case 'FR':
      return Language.fr;
    case 'ES':
      return Language.es;
    case 'RU':
      return Language.ru;
    case 'IT':
      return Language.it;
    case 'EN':
    default:
      return Language.en;
  }
}

class ImagePlaceholderPage extends StatefulWidget {
  const ImagePlaceholderPage({super.key});
  @override
  State<ImagePlaceholderPage> createState() => _ImagePlaceholderPageState();
}

class _ImagePlaceholderPageState extends State<ImagePlaceholderPage> {
  // Image picking
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  File? _croppedImageFile; // The cropped image (if any)

  /// True when the picked file is a PDF rather than an image (Markus,
  /// 2026-07-14: the Image page should accept files/PDFs too). PDFs skip the
  /// cropper (nothing to draw a polygon on) and can't render via Image.file,
  /// so the preview shows a document placeholder instead. Gemini accepts the
  /// PDF straight through as inline_data, same as an image.
  bool get _isPdf =>
      _imageFile != null && _imageFile!.path.toLowerCase().endsWith('.pdf');

  /// A plain-text file. Gemini reads it straight through as text/plain
  /// inline_data, same path as a PDF, so no conversion server is needed.
  bool get _isTextFile =>
      _imageFile != null && _imageFile!.path.toLowerCase().endsWith('.txt');

  /// Loaded file has no bitmap to show (PDF or text).
  bool get _isDocumentFile => _isPdf || _isTextFile;

  /// Which pages of the current PDF to process, e.g. "3" or "2-5". Null =
  /// all pages. Asked once when the PDF is picked (Markus, 2026-07-15:
  /// "maybe you can ask which page of a PDF should be opened") and kept so
  /// re-runs (language switch, retranslate) honor the same choice.
  String? _pdfPageSpec;

  // AI service & state
  final GeminiImageService _chat = GeminiImageService();
  final _ttsService = GeminiTtsService();
  ap.AudioPlayer? _resultPlayer;

  /// Extracts plain, speakable text from the result (JSON segments or HTML).
  String _speakableText() {
    final raw = _resultText.trim();
    if (raw.isEmpty) return '';
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => (e is Map ? e['t']?.toString() : null) ?? '')
            .where((s) => s.isNotEmpty)
            .join('. ');
      }
    } catch (_) {}
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Public so the nav bar (main.dart, via a GlobalKey) can reactively enable
  // the Tutor bulb only while Hungarian text is actually present on this page.
  final ValueNotifier<bool> hasHungarianText = ValueNotifier(false);

  void _updateHasHungarianText() {
    final has = _hungarianText().isNotEmpty;
    if (has == hasHungarianText.value) return;
    // Called from build(), and the nav bar rebuilds on this notifier, so
    // setting it mid-build threw "setState() called during build". Apply it
    // right after the frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) hasHungarianText.value = has;
    });
  }

  /// Extracts the Hungarian segment(s) from the result, whichever side
  /// (original 'o' or translated 't') is currently set to Hungarian.
  String _hungarianText() {
    final raw = _resultText.trim();
    if (raw.isEmpty) return '';
    if (_rightLang != Language.hu && _leftLang != Language.hu) return '';
    final key = _rightLang == Language.hu ? 'o' : 't';
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => (e is Map ? e[key]?.toString() : null) ?? '')
            .where((s) => s.isNotEmpty)
            .join('. ');
      }
    } catch (_) {}
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Tutor: called by the nav bar's bulb button (main.dart, via GlobalKey).
  void openTutor() {
    final hungarianText = _hungarianText();
    if (hungarianText.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    _gemini
        .translate(
          hungarianText,
          _langCode(Language.hu),
          _langCode(_leftLang == Language.hu ? _rightLang : _leftLang),
          explain: true,
          uiLanguage:
              Localizations.localeOf(context).languageCode.toUpperCase(),
        )
        .then((explanation) {
          if (!mounted) return;
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  content: SingleChildScrollView(child: Text(explanation)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.of(context)!.ok),
                    ),
                  ],
                ),
          );
        })
        .catchError((_) {
          if (mounted) Navigator.of(context).pop();
        });
  }

  Future<void> _speakResult() async {
    final text = _speakableText();
    if (text.isEmpty) return;
    try {
      _resultPlayer ??= ap.AudioPlayer();
      await _resultPlayer!.stop();
      final file = await _ttsService.synthesizeSpeech(
        text: text,
        langCode: _langCode(_leftLang),
      );
      await _resultPlayer!.play(ap.DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Image TTS failed: $e');
    }
  }

  /// Opens the "ask a question about this document" modal (Markus,
  /// 2026-07-23 voice note: a "?" button next to a translated PDF/image that
  /// opens a field to type a question about it). The dialog's own labels
  /// (title/hint/buttons) are in the app's UI language via AppLocalizations,
  /// but the generated answer itself follows the selected target language
  /// (_leftLang), same as the translation output (Markus, 2026-07-25 voice
  /// note: "the translations need to go to this defined target language, so
  /// here also the explanation for the PDF file" — this used to answer in
  /// the UI language instead).
  Future<void> _askQuestion() async {
    final doc = _croppedImageFile ?? _imageFile;
    if (doc == null || _isProcessing) return;
    if (!await ensureWiuBalance(context)) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (_) => DocumentQuestionDialog(
            file: doc,
            pdfPages: _isPdf ? _pdfPageSpec : null,
            answerLangCode: _langCode(_leftLang),
          ),
    );
  }

  bool _isProcessing = false;
  // Shown under the loader while _isProcessing (Markus, 2026-08: separate
  // "Converting document..." / "Analyzing and translating..." states so it's
  // clear why Office/text files take an extra moment before translation
  // starts). Empty = no status text (e.g. a plain image/PDF still shows just
  // the loader).
  String _statusText = '';
  String _resultText = '';

  // Caches the last successful result per mode for the currently loaded
  // document, so flipping the translate/explain toggle back to a mode
  // already computed just redisplays it instead of calling Gemini (and
  // spending WIU) again (Markus, 2026-07-24: "store in the cache when I am
  // switching from explanation to translation mode, that it will not
  // calculate again"). Cleared whenever a new document loads or the
  // language pair changes, since either invalidates both results.
  String? _translateResultCache;
  String? _interpretResultCache;

  // Split/drag state
  double _splitRatio = 0.5;
  static const double _dividerH = 10.0;
  double _zoomLevel = 1.0; // Default zoom factor (1x)

  // Pinch-to-zoom for the result panel text. _zoomLevel already fed into the
  // font-size math everywhere below, but nothing ever moved it away from 1.0
  // (Markus, 2026-07-27 voice note: "I am not able to resize it with a
  // finger gesture"). Tracked via raw Listener/pointer events rather than a
  // GestureDetector's scale recognizer, since the latter would compete with
  // the panel's own vertical ScrollView for single-finger drags; Listener
  // only observes events, so normal one-finger scrolling is untouched and
  // only genuine two-finger pinches move the zoom.
  final Map<int, Offset> _resultPointers = {};
  double? _pinchStartDistance;
  double _pinchStartZoom = 1.0;

  void _onResultPointerDown(PointerDownEvent event) {
    _resultPointers[event.pointer] = event.position;
    if (_resultPointers.length == 2) {
      final points = _resultPointers.values.toList();
      _pinchStartDistance = (points[0] - points[1]).distance;
      _pinchStartZoom = _zoomLevel;
    }
  }

  void _onResultPointerMove(PointerMoveEvent event) {
    if (!_resultPointers.containsKey(event.pointer)) return;
    _resultPointers[event.pointer] = event.position;
    final startDistance = _pinchStartDistance;
    if (_resultPointers.length == 2 &&
        startDistance != null &&
        startDistance > 0) {
      final points = _resultPointers.values.toList();
      final currentDistance = (points[0] - points[1]).distance;
      setState(() {
        _zoomLevel = (_pinchStartZoom * currentDistance / startDistance).clamp(
          0.6,
          2.0,
        );
      });
    }
  }

  void _onResultPointerUp(PointerEvent event) {
    _resultPointers.remove(event.pointer);
    if (_resultPointers.length < 2) _pinchStartDistance = null;
  }

  // Capture resolution for the picker. Was maxWidth 512 / quality 70, which
  // is far too small to read a document photo: the text was destroyed before
  // Gemini ever saw it, so it kept reporting the image wasn't clear enough
  // (Markus, 2026-07-14, after photographing a document). 2048px keeps
  // document text legible; the extra Gemini image tokens cost a fraction of
  // a WIU per call, so it's cheap next to a failed read.
  static const double _pickMaxWidth = 2048;
  static const int _pickQuality = 90;

  final GeminiTranslator _gemini =
      GeminiTranslator(); // Already used in your other pages

  // Language switcher state
  Language _leftLang = Language.de;
  Language _rightLang = Language.hu;

  /// True only when essentially NOTHING could be read.
  ///
  /// This used to return true if the result contained "{unsafe}" or
  /// "illegible" anywhere. But the translate prompt marks each individually
  /// unreadable segment as "{unsafe}", and the interpret prompt is told to
  /// say "illegible" for any unclear part. So a document where 29 of 30
  /// segments read perfectly was thrown away wholesale because of the one
  /// blurry line, and the more text the photo had, the more likely that
  /// became (Markus, 2026-07-15: "I was taking a photo with more text and
  /// it's telling me the quality is not good enough"). Now it only rejects
  /// when every segment failed.
  bool _imageIsUnclear(String result) {
    final clean = result.trim();
    if (clean.isEmpty) return true;

    // Interpret mode returns HTML; only the explicit sentinel means failure.
    if (_interpretMode) {
      return clean.toLowerCase().contains("can't understand the image") ||
          clean.toLowerCase().contains('cant understand the image');
    }

    // Translate mode returns a JSON array of {"o":..,"t":..} segments.
    try {
      final decoded = json.decode(stripHtmlCodeFence(clean));
      if (decoded is List) {
        if (decoded.isEmpty) return true;
        final unreadable =
            decoded.where((e) {
              if (e is! Map) return true;
              final o = (e['o'] ?? '').toString().toLowerCase();
              return o.contains('{unsafe}') || o.trim().isEmpty;
            }).length;
        // Only a total failure counts as "not clear".
        return unreadable == decoded.length;
      }
    } catch (_) {
      // Not parseable as JSON: fall through to the conservative check below.
    }

    return clean.toLowerCase().contains('{unsafe}') &&
        !clean.contains('"t"'); // nothing translated at all
  }

  /// True only when Gemini came back with a well-formed but empty JSON
  /// array, i.e. the prompt's own "if you can't detect any text, return []"
  /// instruction fired. That means it looked at the whole document and
  /// found nothing in the selected source language, which is a language
  /// mismatch, not a blurry photo (Markus, 2026-07-15: a PDF titled
  /// "Hungarian-..." that turned out to be English text about Hungarian
  /// art, so selecting Hungarian as source correctly found nothing). Kept
  /// separate from [_imageIsUnclear], which also covers the case where
  /// Gemini found segments but couldn't read them.
  bool _noMatchingLanguageText(String result) {
    if (_interpretMode) return false;
    try {
      final decoded = json.decode(stripHtmlCodeFence(result.trim()));
      return decoded is List && decoded.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveState(File imageFile, String resultText) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('lastImagePath', imageFile.path);
    prefs.setString('lastResultText', resultText);
  }

  // Flag/image and label maps
  final Map<Language, String> _flagPaths = {
    Language.en: 'assets/flags/EN_BW_LS.png',
    Language.de: 'assets/flags/DE_BW_LS.png',
    Language.hu: 'assets/flags/HU_BW_LS.png',
    // No dedicated _BW_LS card flags for these yet — reuse the colored
    // settings-selector flag until Markus sends one.
    Language.nl: 'assets/flags/NL_L.png',
    Language.fr: 'assets/flags/FR_L.png',
    Language.es: 'assets/flags/ES_L.png',
    Language.ru: 'assets/flags/RU_L.png',
    Language.it: 'assets/flags/IT_L.png',
  };
  final Map<Language, String> _labelPaths = {
    Language.en: 'assets/images/EN-EN.png',
    Language.de: 'assets/images/DE-DE.png',
    Language.hu: 'assets/images/HU-HU.png',
    Language.nl: 'assets/images/NL-NL.png',
    Language.fr: 'assets/images/FR-FR.png',
    Language.es: 'assets/images/ES-ES.png',
    Language.ru: 'assets/images/RU-RU.png',
    Language.it: 'assets/images/IT-IT.png',
  };

  String stripHtmlCodeFence(String input) {
    // Remove leading ```html or ```HTML and trailing ```
    final regex = RegExp(
      r'^```html\s*([\s\S]*?)```$',
      multiLine: true,
      caseSensitive: false,
    );
    final match = regex.firstMatch(input.trim());
    if (match != null) {
      return match.group(1)!.trim();
    }
    // If not a code fence but starts with ```html or ends with ```
    if (input.trim().startsWith('```html')) {
      return input
          .trim()
          .substring(7)
          .trim()
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    if (input.trim().startsWith('```')) {
      return input
          .trim()
          .substring(3)
          .trim()
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    return input.trim();
  }

  // Placeholder text for preview
  static const String _placeholderText = '';

  bool _interpretMode = false; // false = translate, true = interpret
  late final ScrollController _scrollController;
  bool _isJsonArray(String str) {
    try {
      final decoded = json.decode(str);
      return decoded is List;
    } catch (_) {
      return false;
    }
  }

  bool _isHtmlDoc(String str) {
    final s = str.trim();
    return s.startsWith('<') && s.endsWith('>');
  }

  /// Salvages a JSON array embedded in extra prose. Gemini sometimes breaks
  /// its own strict-JSON-only instruction and adds commentary (Markus,
  /// 2026-07-10: raw reasoning like `wait, "X" is fully visible` leaked into
  /// the displayed result). Finds the outermost '[' ... ']' and tries to
  /// parse just that; returns null if nothing valid can be recovered.
  String? _extractJsonArray(String str) {
    final start = str.indexOf('[');
    final end = str.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    final candidate = str.substring(start, end + 1);
    try {
      final decoded = json.decode(candidate);
      if (decoded is List) return candidate;
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('lastImagePath');
    final result = prefs.getString('lastResultText');

    if (path != null && File(path).existsSync()) {
      setState(() {
        _imageFile = File(path);
        _croppedImageFile = null; // you could cache cropped version too
        _resultText = result ?? '';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    hasHungarianText.dispose();
    super.dispose();
  }

  // Utility for getting language code for ChatGptService
  String _langCode(Language lang) {
    switch (lang) {
      case Language.en:
        return "EN";
      case Language.de:
        return "DE";
      case Language.hu:
        return "HU";
      case Language.nl:
        return "NL";
      case Language.fr:
        return "FR";
      case Language.es:
        return "ES";
      case Language.ru:
        return "RU";
      case Language.it:
        return "IT";
    }
  }

  // Get next language in the enum, skipping the 'other'. The third slot is
  // whatever the user picked in Settings (defaults to English).
  Language _next(Language current, Language other) {
    final list = [Language.hu, Language.de, _localThirdLang()];
    int i = list.indexOf(current);
    Language next = list[(i + 1) % list.length];
    if (next == other) {
      next = list[(i + 2) % list.length];
    }
    return next;
  }

  void _switchLanguages() {
    setState(() {
      final temp = _leftLang;
      _leftLang = _rightLang;
      _rightLang = temp;
      // Optionally swap result direction (not strictly needed for image)
    });
    if (_imageFile != null) _processImage(imageFile: _imageFile!);
  }

  List<dynamic>? extractFirstJsonArray(String input) {
    final arrayMatch = RegExp(r'(\[[\s\S]*\])').firstMatch(input);
    if (arrayMatch != null) {
      try {
        return json.decode(arrayMatch.group(1)!);
      } catch (e) {
        // still not valid JSON, fallback
        return null;
      }
    }
    return null;
  }

  Widget formattedJsonResult(
    String jsonStr,
    double panelH, {
    bool onlyTranslated = false,
  }) {
    final items = robustJsonArrayExtractor(jsonStr);

    if (items == null) {
      return Text(
        jsonStr,
        style: GoogleFonts.robotoCondensed(fontSize: 22, color: Colors.black),
      );
    }

    double calcFont(String text) {
      const double maxFont = 36;
      const double minFont = 18;
      double scale = (panelH / 200).clamp(0.7, 1.0);
      double scaled = maxFont * scale - (text.length * 0.1);
      if (scaled < minFont) return minFont;
      if (scaled > maxFont) return maxFont;
      return scaled * 0.5; // 👈 halve the font
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items.map<Widget>((item) {
            final orig = (item['o'] ?? '').toString().trim();
            final trans = (item['t'] ?? '').toString().trim();
            if (orig.isEmpty && trans.isEmpty) return const SizedBox.shrink();
            return Padding(
              // Was 8.0 — combined with the oversized 24px flat font this
              // read as too much space between lines (Markus, 2026-07-27).
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!onlyTranslated && orig.isNotEmpty)
                    Text(
                      orig,
                      style: GoogleFonts.robotoCondensed(
                        // Was a flat 24.0, oversized for body text; also
                        // never actually adjustable, _zoomLevel had no
                        // gesture wired to it. Both fixed here.
                        fontSize: 17.0 * _zoomLevel,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                        color: navRed,
                      ),
                    ),
                  if (trans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trans,
                        style: GoogleFonts.robotoCondensed(
                          fontSize: 17.0 * _zoomLevel,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          color: navGreen,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  String stripCodeFence(String input) {
    // Removes any kind of triple-backtick code block, including ```json, ```html, etc.
    final fence = RegExp(
      r'^\s*```[\w]*\s*([\s\S]*?)```$',
      multiLine: true,
      caseSensitive: false,
    );
    final match = fence.firstMatch(input.trim());
    if (match != null) return match.group(1)!.trim();
    // Handles just starting with ```
    if (input.trim().startsWith('```')) {
      return input
          .trim()
          .replaceAll(RegExp(r'^```[\w]*'), '')
          .replaceAll('```', '')
          .trim();
    }
    return input.trim();
  }

  Widget _formattedResult(String resultJson, double panelH) {
    final cleanJson = stripCodeFence(resultJson);
    List<dynamic> items;
    try {
      items = json.decode(cleanJson) as List;
      // ...format your output as widgets...
    } catch (e) {
      // Fallback: show plain text
      return Text(
        cleanJson,
        style: GoogleFonts.robotoCondensed(fontSize: 22, color: Colors.black),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          items.map<Widget>((item) {
            final orig = (item['o'] ?? '').toString().trim();
            final trans = (item['t'] ?? '').toString().trim();

            if (orig.isEmpty && trans.isEmpty) return SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orig.isNotEmpty)
                    Text(
                      orig,
                      style: GoogleFonts.robotoCondensed(
                        fontSize: calculateFontSizes(orig, panelH) * _zoomLevel,
                        fontWeight: FontWeight.bold,
                        color: navRed,
                        letterSpacing: -0.3,
                      ),
                    ),
                  if (trans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trans,
                        style: GoogleFonts.robotoCondensed(
                          fontSize:
                              calculateFontSizes(trans, panelH) * _zoomLevel,
                          fontWeight: FontWeight.w500,
                          color: navGreen,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Future<void> _processImage({required File imageFile}) async {
    if (!await ensureWiuBalance(context)) return;

    setState(() {
      _isProcessing = true;
      _statusText = AppLocalizations.of(context)!.analyzingAndTranslating;
      _resultText = '';
    });
    await _saveState(_croppedImageFile ?? _imageFile!, _resultText);

    try {
      final out = await _chat.processImage(
        imageFile: imageFile,
        translate: !_interpretMode,
        interpret: _interpretMode,
        fromLangCode: _langCode(_rightLang),
        toLangCode: _langCode(_leftLang),
        pdfPages: _isPdf ? _pdfPageSpec : null,
      );

      // The language-mismatch check only makes sense in translate mode, where
      // each JSON segment has an "o" (original) field in the source language.
      // In interpret mode the whole output is already written in the target
      // language, so detecting its language and comparing it against the
      // source language was a guaranteed false mismatch (Markus, 2026-07-10:
      // "explain image" reporting "your language is German" right after a
      // correct Hungarian translation).
      if (!_interpretMode) {
        // Build the detection sample STRICTLY from the extracted "o"
        // (original) segments — never from Gemini's raw reply. The raw reply
        // is a JSON blob (often wrapped in a ```json fence despite the
        // prompt), and asking "what language is this?" about JSON syntax
        // reliably comes back "EN". That was the real cause of a 100%
        // Hungarian utility bill being reported as English (Markus,
        // 2026-07-15): the fence made json.decode throw, the old code fell
        // back to sampleText = raw out, and the detector saw code, not
        // Hungarian.
        String fenceStripped = out.trim();
        final fenceMatch = RegExp(
          r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$',
        ).firstMatch(fenceStripped);
        if (fenceMatch != null) fenceStripped = fenceMatch.group(1)!.trim();

        String sampleText = '';
        try {
          final maybeJson = json.decode(fenceStripped);
          if (maybeJson is List && maybeJson.isNotEmpty) {
            // Use every segment's original text, not just the first, so
            // short/ambiguous fragments don't dominate detection (Markus,
            // 2026-07-10: genuine Hungarian misdetected as Portuguese).
            sampleText = maybeJson
                .map(
                  (e) => (e is Map && e['o'] != null) ? e['o'].toString() : '',
                )
                .where((s) => s.isNotEmpty && !s.contains('{unsafe}'))
                .join(' ');
          }
        } catch (_) {
          // Decode still failed: salvage the "o" values by regex rather
          // than handing raw JSON to the detector.
          sampleText = RegExp(r'"o"\s*:\s*"((?:[^"\\]|\\.)*)"')
              .allMatches(fenceStripped)
              .map((m) => m.group(1)!)
              .where((s) => !s.contains('{unsafe}'))
              .join(' ');
        }

        // Documents like bills are full of dates, amounts and IDs; digits
        // and punctuation say nothing about the language, so the "enough
        // text to judge" guard counts letters only.
        final letterCount =
            RegExp(
              r'[a-zA-ZáéíóöőúüűÁÉÍÓÖŐÚÜŰäöüßÄÖÜàâçèêëîïôùûÀÂÇÈÊËÎÏÔÙÛñÑа-яА-Я]',
            ).allMatches(sampleText).length;

        final langCodes = {
          Language.hu: 'HU',
          Language.de: 'DE',
          Language.en: 'EN',
          Language.nl: 'NL',
          Language.fr: 'FR',
          Language.es: 'ES',
          Language.ru: 'RU',
          Language.it: 'IT',
        };

        String detected = '';
        if (letterCount >= 20) {
          final rawDetected = await _gemini.detectLanguage(sampleText);
          // Normalize the result. Guard the substring so a short/empty
          // result can't throw a RangeError.
          final normalized = rawDetected.toUpperCase().replaceAll('-', '');
          detected =
              normalized.length >= 2 ? normalized.substring(0, 2) : normalized;
        }

        // Only a confident, supported answer may interrupt the user: if the
        // detector answered UNKNOWN, garbage, or something outside the app's
        // 8 languages, silently accept the user's own selection.
        if (detected.isNotEmpty &&
            langCodes.containsValue(detected) &&
            detected != langCodes[_rightLang]) {
          if (mounted) {
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.langMismatch(detected, langCodes[_rightLang] ?? ''),
                    ),
                    actionsPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    actions: [
                      // ❌ CLOSE
                      IconButton(
                        icon: Image.asset(
                          'assets/images/close.png',
                          width: 28,
                          height: 28,
                          color: navRed,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      // ✅ CHECK = apply detected language
                      IconButton(
                        icon: Image.asset(
                          'assets/images/check.png',
                          width: 28,
                          height: 28,
                          color: navGreen,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            final newRightLang =
                                langCodes.entries
                                    .firstWhere((e) => e.value == detected)
                                    .key;
                            setState(() {
                              _rightLang = newRightLang;
                              // Guard against both sides ending up on the same
                              // language (e.g. accepting "detected DE" while
                              // the left side is already DE).
                              if (_leftLang == newRightLang) {
                                _leftLang = _next(_leftLang, newRightLang);
                              }
                              _translateResultCache = null;
                              _interpretResultCache = null;
                            });
                            if (_imageFile != null) {
                              _processImage(imageFile: _imageFile!);
                            }
                          });
                        },
                      ),
                    ],
                  ),
            );
          }
          setState(() {
            _isProcessing = false;
            _resultText = '';
          });
          return;
        }
      }

      final cleaned = out.trim();
      setState(() {
        _resultText = cleaned;
        if (_interpretMode) {
          _interpretResultCache = cleaned;
        } else {
          _translateResultCache = cleaned;
        }
      });
      await _saveState(_croppedImageFile ?? _imageFile!, cleaned);
      if (cleaned.isNotEmpty && !cleaned.startsWith("Error:")) {
        await _saveState(_croppedImageFile ?? _imageFile!, cleaned);
      }

      if (_noMatchingLanguageText(out)) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.noTextFoundTitle),
                content: Text(
                  AppLocalizations.of(
                    context,
                  )!.noTextFoundBody(_langCode(_rightLang)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.ok),
                  ),
                ],
              ),
        );
      } else if (_imageIsUnclear(out)) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.imageNotClear),
                content: Text(AppLocalizations.of(context)!.imageNotClearBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context)!.ok),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      debugPrint('Image processing failed: $e');
      // Show errors as a toast, not in the result box.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.serviceUnavailable),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = '';
        });
      }
    }
  }

  /// After a TARGET-language change in translate mode: re-translates the
  /// segments already read from the image instead of sending the image again
  /// (Markus, video of 2026-09-29: "it is calculating again... the text was
  /// already here"). [previousResult] is the translate result from before the
  /// change. Returns false when that isn't possible (nothing extracted yet,
  /// unexpected format), so the caller can fall back to [_processImage].
  Future<bool> _retranslateExtractedText(String? previousResult) async {
    if (_interpretMode || previousResult == null) return false;
    var raw = previousResult.trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*([\s\S]*?)\s*```$').firstMatch(raw);
    if (fence != null) raw = fence.group(1)!.trim();

    final List<Map<String, dynamic>> segments;
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return false;
      segments = [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return false;
    }
    // Illegible segments stay "{unsafe}"; only real text is re-translated.
    final readable = [
      for (final s in segments)
        if (s['o'] != null && !s['o'].toString().contains('{unsafe}')) s,
    ];
    if (readable.isEmpty) return false;
    if (!await ensureWiuBalance(context)) return true;
    if (!mounted) return true;

    setState(() {
      _isProcessing = true;
      _statusText = AppLocalizations.of(context)!.analyzingAndTranslating;
      _resultText = '';
    });
    try {
      final translations = await _chat.retranslateSegments(
        originals: [for (final s in readable) s['o'].toString()],
        fromLangCode: _langCode(_rightLang),
        toLangCode: _langCode(_leftLang),
      );
      for (var i = 0; i < readable.length; i++) {
        readable[i]['t'] = translations[i];
      }
      final cleaned = json.encode(segments);
      if (!mounted) return true;
      setState(() {
        _resultText = cleaned;
        _translateResultCache = cleaned;
      });
      await _saveState(_croppedImageFile ?? _imageFile!, cleaned);
      return true;
    } catch (e) {
      // Malformed reply or network trouble: fall back to the full re-read
      // so the user still gets a result.
      debugPrint('Re-translating extracted text failed, re-reading: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _pickMaxWidth,
      imageQuality: _pickQuality,
    );
    if (picked != null) {
      File file = File(picked.path);
      final cropped = await Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (_) => ImageCropperPage(imageFile: file)),
      );

      setState(() {
        _imageFile = file;
        _croppedImageFile = cropped;
      });

      await _processImage(imageFile: cropped ?? file);
    }
  }

  /// "Load from device" entry point: asks whether to pick a photo from the
  /// gallery or a document from files. These are separate pickers on both
  /// platforms (Photos vs Files on iOS, gallery vs document picker on
  /// Android), so replacing the gallery with the file picker outright would
  /// have taken the photo library away (Markus, 2026-07-15: "Load From
  /// should give you the option to pick from gallery or files").
  Future<void> _showLoadSourceSheet() async {
    final loc = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: navRed),
                  title: Text(
                    loc.pickFromGallery,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open, color: navRed),
                  title: Text(
                    loc.pickFromFiles,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('files'),
                ),
              ],
            ),
          ),
    );
    if (source == 'gallery') {
      await _pickFromGallery();
    } else if (source == 'files') {
      await _pickFromFiles();
    }
  }

  /// Photo library (image_picker). Always an image, so it goes through the
  /// cropper.
  Future<void> _pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _pickMaxWidth,
      imageQuality: _pickQuality,
    );
    if (picked == null) return;
    await _loadImageWithCropper(File(picked.path));
  }

  /// Extensions Gemini can't read directly, so they're converted to PDF via
  /// our own LibreOffice-backed service first, then handled exactly like an
  /// uploaded PDF (Markus, 2026-08 proposal). Only offered in the file picker
  /// once that service is configured: until then every pick failed with the
  /// "conversion failed" dialog. TXT is no longer here, it needs no
  /// conversion (see [_isTextFile]).
  static const _officeExtensions = {
    'doc',
    'docx',
    'xls',
    'xlsx',
    'odt',
    'ods',
  };

  final _conversionService = DocumentConversionService();

  /// Device files: images (which still go through the cropper), PDFs, and
  /// Office/text documents (converted to PDF first) — all three end up
  /// either in the cropper flow or the PDF page-picker flow. Markus,
  /// 2026-07-14 (PDF support), 2026-08 (Office/text via conversion).
  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
        'pdf',
        'txt',
        if (_conversionService.isConfigured) ..._officeExtensions,
      ],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final extension = path.split('.').last.toLowerCase();
    File file = File(path);

    if (extension == 'txt') {
      // Plain text: no pages to pick and nothing to crop; send it as is.
      setState(() {
        _imageFile = file;
        _croppedImageFile = null;
        _pdfPageSpec = null;
        _resultText = '';
        _translateResultCache = null;
        _interpretResultCache = null;
      });
      await _processImage(imageFile: file);
      return;
    }

    if (_officeExtensions.contains(extension)) {
      final converted = await _convertOfficeDocument(file);
      if (converted == null) return; // failure already shown to the user
      file = converted;
    } else if (extension != 'pdf') {
      _pdfPageSpec = null;
      await _loadImageWithCropper(file);
      return;
    }

    // PDF (uploaded directly, or converted from an Office/text document):
    // nothing to crop. Let the user tick the pages to process on a visual
    // preview before spending tokens on the whole document (Markus,
    // 2026-07-16: pick the pages instead of typing a page number).
    if (!mounted) return;
    final selected = await showDialog<List<int>?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PdfPageSelectorDialog(file: file),
    );
    if (selected == null || selected.isEmpty) return; // cancelled
    // Clear the previous document's result here, not just inside
    // _processImage: if the WIU balance check blocks that call, the old
    // text was otherwise left on screen next to the newly loaded document
    // (Markus, 2026-07-24: after loading a new file "you need to delete
    // the lower panel").
    setState(() {
      _imageFile = file;
      _croppedImageFile = null;
      _pdfPageSpec = _pagesToSpec(selected);
      _resultText = '';
      _translateResultCache = null;
      _interpretResultCache = null;
    });
    await _processImage(imageFile: file);
  }

  /// Converts an Office/text file to PDF via [DocumentConversionService],
  /// showing the same status text convention as [_processImage]. Returns
  /// null (having already shown [conversionFailedTitle]) on any failure.
  Future<File?> _convertOfficeDocument(File file) async {
    setState(
      () => _statusText = AppLocalizations.of(context)!.convertingDocument,
    );
    try {
      return await _conversionService.convertToPdf(file);
    } catch (e) {
      debugPrint('Document conversion failed: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(loc.conversionFailedTitle),
                content: Text(loc.conversionFailedBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.ok),
                  ),
                ],
              ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _statusText = '');
    }
  }

  /// Turns a sorted list of page numbers into a compact spec for the Gemini
  /// prompt, collapsing runs into ranges: [1,2,3,5] -> "1-3,5".
  String _pagesToSpec(List<int> pages) {
    final parts = <String>[];
    var start = pages.first;
    var prev = pages.first;
    for (final p in pages.skip(1)) {
      if (p == prev + 1) {
        prev = p;
        continue;
      }
      parts.add(start == prev ? '$start' : '$start-$prev');
      start = prev = p;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return parts.join(',');
  }

  Future<void> _loadImageWithCropper(File file) async {
    if (!mounted) return;
    final cropped = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ImageCropperPage(imageFile: file)),
    );

    setState(() {
      _imageFile = file;
      _croppedImageFile = cropped;
      _pdfPageSpec = null; // images have no page selection
      _resultText = ''; // clear the previous document's result immediately
      _translateResultCache = null;
      _interpretResultCache = null;
    });

    await _processImage(imageFile: cropped ?? file);
  }

  bool _laActive = false;

  @override
  Widget build(BuildContext context) {
    _updateHasHungarianText();
    final double boxW =
        MediaQuery.of(context).size.width.clamp(0, 486).toDouble() - 32;
    final double switcherW =
        (MediaQuery.of(context).size.width * 0.85).clamp(0, 350).toDouble();
    const double switcherH = 55;
    const double flagSize = 50;
    const double switchSize = 50;
    final screenWidth = MediaQuery.of(context).size.width;
    final double iconSize = (screenWidth * 0.085).clamp(24.0, 48.0);
    return Container(
      color: Colors.white,
      // No top or bottom padding of its own: the global body/nav-bar gaps
      // (main.dart) already provide both. A local top: 30 here stacked onto
      // the global 30 and made this the most top-heavy page in the app
      // (spacing audit, 2026-07-13). Left/right stay on the 16 grid.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ─── Top & Bottom panels separated by draggable divider ───
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                const double minPanel = 80.0;

                final totalH = constraints.maxHeight;
                final usable = (totalH - _dividerH).clamp(
                  minPanel * 2,
                  totalH - _dividerH,
                );

                final topH = (_splitRatio * usable).clamp(
                  minPanel,
                  usable - minPanel,
                );
                final bottomH = usable - topH;

                return Column(
                  children: [
                    // ─── Top panel ──────────────────────────────
                    Center(
                      child: SizedBox(
                        width: boxW,
                        height: topH,
                        child: Stack(
                          children: [
                            // White rounded box with image or placeholder
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    _isDocumentFile
                                        // A PDF or text file has no bitmap to
                                        // show, so display the filename
                                        // instead of failing an Image.file
                                        // decode.
                                        ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _isPdf
                                                    ? Icons.picture_as_pdf
                                                    : Icons.description,
                                                size: 72,
                                                color: navRed,
                                              ),
                                              const SizedBox(height: 10),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Text(
                                                  _imageFile!.path
                                                      .split(RegExp(r'[/\\]'))
                                                      .last,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      GoogleFonts.robotoCondensed(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : (_croppedImageFile ?? _imageFile) !=
                                            null
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              return InteractiveViewer(
                                                panEnabled: true,
                                                boundaryMargin:
                                                    const EdgeInsets.all(100),
                                                clipBehavior: Clip.none,
                                                minScale: 0.5,
                                                maxScale: 5.0,
                                                constrained: true,
                                                child: SizedBox(
                                                  width: constraints.maxWidth,
                                                  height: constraints.maxHeight,
                                                  child: Image.file(
                                                    _croppedImageFile ??
                                                        _imageFile!,
                                                    fit:
                                                        BoxFit
                                                            .contain, // this ensures it’s zoomed out by default
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                        : /* ... your placeholder content here ... */ Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Camera and file/PDF side by
                                            // side, so loading a PDF is a
                                            // visible option and not only a
                                            // text link (Markus, 2026-07-15).
                                            // Icons + wording supplied by
                                            // Markus, 2026-07-24: photo icon
                                            // + line 1 open the camera, PDF
                                            // icon + line 3 open the file
                                            // dialog.
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: _takePhoto,
                                                  child: Image.asset(
                                                    'assets/png24/black/b_photo.png',
                                                    width: 72,
                                                    height: 72,
                                                  ),
                                                ),
                                                const SizedBox(width: 28),
                                                GestureDetector(
                                                  onTap: _showLoadSourceSheet,
                                                  child: Image.asset(
                                                    'assets/png24/black/b_pdf.png',
                                                    width: 72,
                                                    height: 72,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Markus, 2026-07-24: "Bit more
                                            // space between icons and text"
                                            // (was 8).
                                            const SizedBox(height: 16),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2.0,
                                                  ),
                                              child: Column(
                                                children: [
                                                  GestureDetector(
                                                    onTap: _takePhoto,
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      )!.uploadAreaTakePhoto,
                                                      style:
                                                          GoogleFonts.robotoCondensed(
                                                            fontSize: 26,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.uploadAreaOr,
                                                    style:
                                                        GoogleFonts.robotoCondensed(
                                                          fontSize: 26,
                                                          color: Colors.black,
                                                        ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: _showLoadSourceSheet,
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      )!.uploadAreaUploadFile,
                                                      style:
                                                          GoogleFonts.robotoCondensed(
                                                            fontSize: 26,
                                                            color: Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                            // Trash (discard) + camera (retake) at bottom
                            // left when there's an image, replacing the old
                            // single close(X) button.
                            if ((_croppedImageFile ?? _imageFile) != null)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.remove('lastImagePath');
                                        await prefs.remove('lastResultText');

                                        setState(() {
                                          _imageFile = null;
                                          _croppedImageFile = null;
                                          _pdfPageSpec = null;
                                          _resultText = '';
                                          _translateResultCache = null;
                                          _interpretResultCache = null;
                                          _isProcessing = false;
                                          _laActive = false;
                                          _interpretMode = false;
                                          _splitRatio = 0.5;
                                        });
                                      },
                                      child: Image.asset(
                                        'assets/png24/black/b_garbage.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _takePhoto,
                                      child: Image.asset(
                                        'assets/png24/black/b_photo.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                    // Load a file/PDF. Without this the only
                                    // way in was the "load up from" text link
                                    // on the empty placeholder, so once a
                                    // photo was loaded there was no way to
                                    // reach it (Markus, 2026-07-15: "I can't
                                    // find where I can upload a PDF").
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _showLoadSourceSheet,
                                      child: Image.asset(
                                        // Was the generic document glyph;
                                        // swapped for Markus's PDF icon to
                                        // match the empty-state icons
                                        // (2026-07-24: "replace the third
                                        // small icon in upper panel with the
                                        // new pdf file").
                                        'assets/png24/black/b_pdf.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // ─── Draggable divider ────────────────────
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanUpdate:
                          (d) => setState(() {
                            // Compute the *current* top from your state-backed _splitRatio:
                            final currentTop = _splitRatio * usable;
                            final newTop = (currentTop + d.delta.dy).clamp(
                              minPanel,
                              usable - minPanel,
                            );
                            _splitRatio = newTop / usable;
                          }),

                      child: Container(
                        width: boxW,
                        height: _dividerH,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: boxW * 0.5,
                            height: 4,
                            color: Colors.black26,
                          ),
                        ),
                      ),
                    ),

                    // ─── Bottom panel with auto-sized AI response ───
                    SizedBox(
                      width: boxW,
                      height: bottomH,
                      child: LayoutBuilder(
                        builder: (ctx2, panelConstraints) {
                          final panelH = panelConstraints.maxHeight;
                          final panelW = panelConstraints.maxWidth;
                          const iconRowH = 48.0;
                          final availH = panelH - iconRowH - 16;

                          // pick a font size that fits (same logic)
                          final sizes = [40.0, 35.0, 30.0, 25.0, 18.0, 12.0];
                          double chosenSize = sizes.last;
                          for (final s in sizes) {
                            final tp = TextPainter(
                              text: TextSpan(
                                text:
                                    _resultText.isNotEmpty
                                        ? _resultText
                                        : _placeholderText,
                                style: TextStyle(fontSize: s),
                              ),
                              textDirection: TextDirection.ltr,
                              maxLines: null,
                            )..layout(maxWidth: panelW);
                            if (tp.height <= availH) {
                              chosenSize = s;
                              break;
                            }
                          }

                          // ...rest of your bottom panel widget...
                          // (keep as in your code, passing chosenSize)
                          return Stack(
                            children: [
                              // white background
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: AssetImage(
                                      'assets/images/bg-bright.jpg',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // ... keep your other bottom panel widgets ...
                              // just make sure you use chosenSize in the HTML/Text!
                              if (_isProcessing)
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/loader.gif',
                                        width: 100,
                                        height: 100,
                                      ),
                                      if (_statusText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            _statusText,
                                            style:
                                                GoogleFonts.robotoCondensed(
                                                  fontSize: 16,
                                                  color: navRed,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  bottom: iconRowH + 8,
                                  child: Listener(
                                    onPointerDown: _onResultPointerDown,
                                    onPointerMove: _onResultPointerMove,
                                    onPointerUp: _onResultPointerUp,
                                    onPointerCancel: _onResultPointerUp,
                                    child: Scrollbar(
                                      controller: _scrollController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        child: Builder(
                                          builder: (_) {
                                            final panelH =
                                                panelConstraints.maxHeight;
                                            final panelW =
                                                panelConstraints.maxWidth;
                                            final res =
                                                _resultText.isNotEmpty
                                                    ? _resultText
                                                    : _placeholderText;
                                            final htmlStr = stripHtmlCodeFence(
                                              res,
                                            );
                                            final salvagedJson =
                                                _isJsonArray(res)
                                                    ? res
                                                    : _extractJsonArray(res);
                                            if (salvagedJson != null) {
                                              return formattedJsonResult(
                                                salvagedJson,
                                                panelH,
                                                onlyTranslated:
                                                    _laActive, // Hide original if LA is active
                                              );
                                            } else if (_isHtmlDoc(htmlStr)) {
                                              return Html(
                                                data: htmlStr,
                                                style: {
                                                  "body": Style(
                                                    fontSize: FontSize(
                                                      calculateFontSizes(
                                                            res,
                                                            panelH,
                                                          ) *
                                                          _zoomLevel,
                                                    ),
                                                    // Tighter than the
                                                    // library's 1.2 default,
                                                    // paired with the smaller
                                                    // font above (Markus,
                                                    // 2026-07-27: "spacing
                                                    // between the lines are
                                                    // really big").
                                                    lineHeight:
                                                        LineHeight.number(0.95),
                                                    fontFamily:
                                                        GoogleFonts.robotoCondensed()
                                                            .fontFamily,
                                                  ),
                                                },
                                              );
                                            } else {
                                              // Non-empty but neither valid
                                              // JSON nor HTML: Gemini broke its
                                              // own strict-output format
                                              // (Markus, 2026-07-10: raw
                                              // reasoning text leaked into the
                                              // result). Never show that raw
                                              // text — fall back to a clean
                                              // message, same as an unclear
                                              // image. Empty/placeholder text
                                              // still renders as before.
                                              final shown =
                                                  res.isEmpty
                                                      ? res
                                                      : AppLocalizations.of(
                                                        context,
                                                      )!.imageNotClearBody;
                                              return Text(
                                                shown,
                                                style:
                                                    GoogleFonts.robotoCondensed(
                                                      fontSize:
                                                          calculateFontSizes(
                                                            shown,
                                                            panelH,
                                                          ) *
                                                          _zoomLevel,
                                                      letterSpacing: -0.3,
                                                    ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // icon row (copy/share/zoom/etc)
                              Positioned(
                                bottom: 8,
                                left: 16,
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final textToCopy =
                                            _resultText.isNotEmpty
                                                ? _resultText
                                                : _placeholderText;
                                        Clipboard.setData(
                                          ClipboardData(text: textToCopy),
                                        );
                                        showCopiedToast(
                                          context,
                                          AppLocalizations.of(
                                            context,
                                          )!.copiedToClipboard,
                                        );
                                      },
                                      child: Image.asset(
                                        'assets/png24/black/b_copy.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                    // SizedBox(width: iconSize * 0.5),
                                    // Image.asset(
                                    //   'assets/images/share.png',
                                    //   width: iconSize,
                                    //   height: iconSize,
                                    // ),
                                    // SizedBox(width: iconSize * 0.5),
                                    // Image.asset(
                                    //   'assets/images/zoom.png',
                                    //   width: iconSize,
                                    //   height: iconSize,
                                    // ),
                                    // SizedBox(width: iconSize * 0.5),
                                    // Icon(Icons.volume_up, size: iconSize),
                                    SizedBox(width: iconSize * 0.5),
                                    // Share
                                    GestureDetector(
                                      onTap: () {
                                        if (_resultText.isNotEmpty) {
                                          Share.share(_resultText);
                                        }
                                      },
                                      child: Image.asset(
                                        'assets/png24/black/b_share.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    // Fullscreen: was only toggling a flag
                                    // nothing read (Markus, 2026-07-10: "the
                                    // zoom button is not working"). Now opens
                                    // the same landscape zoom view used on
                                    // the conversation cards.
                                    GestureDetector(
                                      onTap: () {
                                        final zoomText = _speakableText();
                                        if (zoomText.isEmpty) return;
                                        showDialog(
                                          context: context,
                                          builder:
                                              (_) => LandscapeZoomModal(
                                                text: zoomText,
                                              ),
                                        );
                                      },
                                      child: Image.asset(
                                        'assets/png24/black/b_fullscreen.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),

                                    SizedBox(width: iconSize * 0.5),
                                    GestureDetector(
                                      onTap: () {
                                        final cached =
                                            !_interpretMode
                                                ? _interpretResultCache
                                                : _translateResultCache;
                                        setState(() {
                                          _interpretMode = !_interpretMode;
                                          if (cached != null) {
                                            _resultText = cached;
                                          } else if (_imageFile != null) {
                                            _processImage(
                                              imageFile: _imageFile!,
                                            );
                                          }
                                        });
                                      },
                                      // Distinct glyph per mode: the asset for
                                      // explanation mode (b_explain_image.png)
                                      // was supplied but never wired up, so
                                      // the button showed the translate icon
                                      // even while explaining. No background
                                      // highlight, the glyph itself is the
                                      // only signal now (Markus, 2026-07-25:
                                      // "nearly correct. But NO grey
                                      // background behind explain button").
                                      child: Container(
                                        padding: EdgeInsets.all(
                                          iconSize * 0.12,
                                        ),
                                        child: Image.asset(
                                          _interpretMode
                                              ? 'assets/png24/black/b_explain_image.png'
                                              : 'assets/png24/black/b_translate.png',
                                          width: iconSize,
                                          height: iconSize,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: iconSize * 0.5),
                                    // Right beside the mode button: the
                                    // ask-question icon only in explanation
                                    // mode, the one/both-language toggle only
                                    // in translate mode — mutually exclusive,
                                    // so the slot is never empty (Markus,
                                    // 2026-07-25: "This question icon must
                                    // only be shown, when explanation mode is
                                    // active").
                                    _interpretMode
                                        ? GestureDetector(
                                          onTap: _askQuestion,
                                          child: Image.asset(
                                            'assets/png24/black/b_ask_question.png',
                                            width: iconSize,
                                            height: iconSize,
                                          ),
                                        )
                                        : GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _laActive = !_laActive;
                                            });
                                          },
                                          child: Image.asset(
                                            _laActive
                                                ? 'assets/png24/black/b_one_language.png'
                                                : 'assets/png24/black/b_both_languages.png',
                                            width: iconSize,
                                            height: iconSize,
                                          ),
                                        ),
                                    SizedBox(width: iconSize * 0.5),
                                    // Speaker — read the translated result
                                    // aloud. Last icon in the row.
                                    GestureDetector(
                                      onTap: _speakResult,
                                      child: Image.asset(
                                        'assets/png24/black/b_speaker.png',
                                        width: iconSize,
                                        height: iconSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Was 33 (two flag stripes), then 16 (md) — still read as too
          // much combined with the nav-bar's own gap below the switcher
          // (Markus, 2026-07-14, after testing +39). Down to sm.
          const SizedBox(height: Spacing.sm),

          // ─── Language switcher (BOTTOM, just like Document page) ──────────
          SizedBox(
            width: switcherW,
            height: switcherH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Right (input language, flag at bottom right, tap cycles)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _rightLang = _next(_rightLang, _leftLang);

                      // clear old output
                      _resultText = '';
                      _translateResultCache = null;
                      _interpretResultCache = null;
                      _isProcessing = false;
                      _laActive = false;
                      _zoomLevel = 1.0;
                    });
                    if (_imageFile != null) {
                      _processImage(imageFile: _imageFile!);
                    }
                  },
                  child: Row(
                    children: [
                      Image.asset(_labelPaths[_rightLang]!, height: 32),
                      const SizedBox(width: 8),
                      Image.asset(
                        _flagPaths[_rightLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 25),
                // Swap button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      // swap
                      final tmp = _leftLang;
                      _leftLang = _rightLang;
                      _rightLang = tmp;

                      // clear old output
                      _resultText = '';
                      _translateResultCache = null;
                      _interpretResultCache = null;
                      _isProcessing = false;
                      _laActive = false;
                      _zoomLevel = 1.0;
                    });

                    // re-run if we have an image
                    if (_imageFile != null) {
                      _processImage(imageFile: _imageFile!);
                    }
                  },
                  child: Image.asset(
                    'assets/png24/black/b_change_flat.png',
                    width: switchSize,
                  ),
                ),
                const SizedBox(width: 25),
                // Left (output language, flag at top left, tap cycles)
                GestureDetector(
                  onTap: () async {
                    // Only the target changes, so the text already read from
                    // the image can be re-translated without re-reading it.
                    final previousResult =
                        _interpretMode ? null : _translateResultCache;
                    setState(() {
                      _leftLang = _next(_leftLang, _rightLang);

                      // clear old output
                      _resultText = '';
                      _translateResultCache = null;
                      _interpretResultCache = null;
                      _isProcessing = false;
                      _laActive = false;
                      _zoomLevel = 1.0;
                    });
                    if (_imageFile != null &&
                        !await _retranslateExtractedText(previousResult)) {
                      _processImage(imageFile: _imageFile!);
                    }
                  },

                  child: Row(
                    children: [
                      Image.asset(
                        _flagPaths[_leftLang]!,
                        width: flagSize,
                        height: flagSize,
                      ),
                      const SizedBox(width: 8),
                      Image.asset(_labelPaths[_leftLang]!, height: 32),
                    ],
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
