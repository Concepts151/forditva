import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database.dart';
import '../models/language_enum.dart';

/// Saves finished translations to the History list (and so to Favorites,
/// which are starred History entries), honouring the "Save History" switch in
/// Settings.
///
/// Before this, only the Document page's inline check button ever wrote to
/// the database, so History stayed empty for Conversation, voice, the edit
/// panel and paste (Markus's demo video, 2026-09-29: "it's not showing").
class HistoryStore {
  static const _enabledKey = 'save_history';
  static bool _enabled = true;

  /// The "Save History" switch in Settings (on by default).
  static bool get enabled => _enabled;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Records one finished translation. Skips empty or unchanged text and
  /// exact duplicates. Never throws: a failed save must not break the
  /// translation the user is looking at.
  static Future<void> save({
    required String input,
    required String output,
    required Language from,
    required Language to,
  }) async {
    if (!_enabled) return;
    final i = input.trim();
    final o = output.trim();
    if (i.isEmpty || o.isEmpty || i == o) return;
    try {
      final dao = AppDatabase.instance.translationDao;
      if (await dao.findExactMatch(i, o) != null) return;
      await dao.insertTranslation(
        TranslationsCompanion.insert(
          input: i,
          output: o,
          fromLang: from.label,
          toLang: to.label,
        ),
      );
    } catch (e) {
      debugPrint('History save failed: $e');
    }
  }

  /// "Clear entire history" in Settings. Favorites are starred history
  /// entries, so they are deleted too.
  static Future<void> clear() =>
      AppDatabase.instance.translationDao.deleteAll();
}
