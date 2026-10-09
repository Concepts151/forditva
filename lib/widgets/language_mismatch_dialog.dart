import 'package:flutter/material.dart';
import 'package:forditva/services/gemini_translation_service.dart';
import 'package:google_fonts/google_fonts.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';

const Color _navRed = Color(0xFFCD2A3E);
const Color _navGreen = Color(0xFF436F4D);

/// Two-letter codes of every language the app can translate.
const supportedLanguageCodes = ['HU', 'DE', 'EN', 'NL', 'FR', 'ES', 'RU', 'IT'];

/// Localized language name for a two-letter code ("HU" -> "Hungarian").
/// Falls back to the code itself for anything unknown.
String languageNameForCode(BuildContext context, String code) {
  final loc = AppLocalizations.of(context)!;
  switch (code.toUpperCase()) {
    case 'HU':
      return loc.languageNameHu;
    case 'DE':
      return loc.languageNameDe;
    case 'EN':
      return loc.languageNameEn;
    case 'NL':
      return loc.languageNameNl;
    case 'FR':
      return loc.languageNameFr;
    case 'ES':
      return loc.languageNameEs;
    case 'RU':
      return loc.languageNameRu;
    case 'IT':
      return loc.languageNameIt;
  }
  return code;
}

/// Detects the language of [text] and returns its two-letter code, or null
/// when the detector is unsure or answers with a language the app does not
/// support. Only a confident, supported answer may interrupt the user.
Future<String?> detectSupportedLanguageCode(
  String text,
  GeminiTranslator gemini,
) async {
  if (text.trim().isEmpty) return null;
  try {
    final raw = await gemini.detectLanguage(text);
    final normalized = raw.toUpperCase().replaceAll('-', '').trim();
    final code =
        normalized.length >= 2 ? normalized.substring(0, 2) : normalized;
    return supportedLanguageCodes.contains(code) ? code : null;
  } catch (_) {
    return null;
  }
}

/// The one panel every page shows when the chosen source language does not
/// match the text (Markus, 2026-10-09: "handle it more globally"). Replaces
/// four separate dialogs that each looked and worded it differently and
/// showed codes ("EN-Text") instead of language names.
///
/// With a [detectedCode] it says "This text is in German, not Hungarian." and
/// offers [Use German] / [Cancel]; returns true when the user picks the
/// detected language. Without one (the language could not be told) it only
/// says no [selectedCode] text was found, with an OK button, and returns
/// false. Callers leave the source language unchanged on false.
Future<bool> showLanguageMismatchDialog(
  BuildContext context, {
  required String selectedCode,
  String? detectedCode,
}) async {
  final loc = AppLocalizations.of(context)!;
  final selected = languageNameForCode(context, selectedCode);
  final detected =
      detectedCode == null ? null : languageNameForCode(context, detectedCode);

  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => Dialog(
          // Same look as the app's own modals (DocumentQuestionDialog,
          // PDF page picker), not Material's default tinted AlertDialog.
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.wrongLanguage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  detected == null
                      ? loc.languageNotFoundBody(selected)
                      : loc.languageMismatchBody(detected, selected),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoCondensed(fontSize: 19),
                ),
                const SizedBox(height: 22),
                Row(
                  children:
                      detected == null
                          ? [
                            Expanded(
                              child: _pillButton(
                                label: loc.ok,
                                color: _navGreen,
                                onTap: () => Navigator.of(ctx).pop(false),
                              ),
                            ),
                          ]
                          : [
                            Expanded(
                              child: _pillButton(
                                label: loc.cancel,
                                color: _navRed,
                                onTap: () => Navigator.of(ctx).pop(false),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _pillButton(
                                label: loc.languageMismatchUse(detected),
                                color: _navGreen,
                                onTap: () => Navigator.of(ctx).pop(true),
                              ),
                            ),
                          ],
                ),
              ],
            ),
          ),
        ),
  );
  return result ?? false;
}

/// Filled pill button, as in the app's other modals.
Widget _pillButton({
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: GoogleFonts.robotoCondensed(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
