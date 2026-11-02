import 'package:flutter/material.dart';

import '../tutor/tutor_page.dart';

/// Opens the Tutor page for [hungarianText] from History and Favorites
/// (Markus's request: revisit the grammar of any past translation). Since
/// 2026-10-09 this is the new three-tab Tutor page instead of the old
/// dialog. [otherLangCode] is the entry's non-Hungarian language.
Future<void> showTutorExplanation({
  required BuildContext context,
  required String hungarianText,
  String? otherLangCode,
  // Kept for existing callers; the Tutor page picks the language itself.
  String uiLang = 'DE',
  String level = 'A2',
}) async {
  TutorLauncher.open(hungarianText, otherLangCode: otherLangCode);
}
