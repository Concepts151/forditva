import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/learning_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('purgeOld removes entries older than 3 months, once a month', () async {
    final now = DateTime(2026, 11, 2);
    SharedPreferences.setMockInitialValues({
      'learning_entries':
          '[{"id":"1","sentence":"old","explanation":"x","createdAt":"${now.subtract(const Duration(days: 100)).toIso8601String()}"},'
          '{"id":"2","sentence":"new","explanation":"x","createdAt":"${now.subtract(const Duration(days: 10)).toIso8601String()}"}]',
    });
    await LearningStore.purgeOld(now: now);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('learning_entries'), contains('"new"'));
    expect(prefs.getString('learning_entries'), isNot(contains('"old"')));

    // A second run within 30 days does nothing, even for newly old entries.
    await prefs.setString(
      'learning_entries',
      '[{"id":"3","sentence":"older","explanation":"x","createdAt":"${now.subtract(const Duration(days: 200)).toIso8601String()}"}]',
    );
    await LearningStore.purgeOld(now: now.add(const Duration(days: 5)));
    expect(prefs.getString('learning_entries'), contains('older'));
    await LearningStore.purgeOld(now: now.add(const Duration(days: 31)));
    expect(prefs.getString('learning_entries'), isNot(contains('older')));
  });
}
