import 'package:shared_preferences/shared_preferences.dart';

/// The user's numeric language level (1-99), set in Settings and used to pick
/// the Tutor's CEFR level. Mapping (per Markus): 1-33 = A1, 34-66 = A2,
/// 67-99 = B1.
class LevelPref {
  static const _key = 'language_level';
  static int _level = 27;

  static int get level => _level;

  static String get cefr => cefrFor(_level);

  static String cefrFor(int level) {
    if (level <= 33) return 'A1';
    if (level <= 66) return 'A2';
    return 'B1';
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _level = prefs.getInt(_key) ?? 27;
  }

  static Future<void> set(int level) async {
    _level = level.clamp(1, 99);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _level);
  }
}
