import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_enum.dart';

/// The user's chosen replacement for English as the flexible third language
/// alongside the fixed Hungarian/German pair (Settings > "dritte Sprache").
/// Held in memory after the first load so every page can read it
/// synchronously, and persisted so the choice survives app restarts.
class ThirdLanguagePref {
  ThirdLanguagePref._();

  static const _key = 'third_language';
  static Language _current = Language.english;
  static final ValueNotifier<Language> notifier = ValueNotifier(
    Language.english,
  );

  static Language get current => _current;

  /// Two-letter code (e.g. "NL"), for pages that can't import the shared
  /// Language type directly (image_page.dart keeps its own local enum of
  /// the same name and would collide with it).
  static String get currentCode => _current.label;

  /// A page may only show Hungarian, German and the current third language.
  /// Any other language (e.g. English kept from the app-language start pair
  /// after Dutch was chosen in Settings) becomes the current third language
  /// (Markus, 2026-10-09).
  static Language normalize(Language language) =>
      language == Language.hungarian || language == Language.german
          ? language
          : _current;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final match = thirdLanguageOptions.where((l) => l.name == stored);
    if (match.isNotEmpty) {
      _current = match.first;
      notifier.value = _current;
    }
  }

  static Future<void> set(Language language) async {
    _current = language;
    notifier.value = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }
}
