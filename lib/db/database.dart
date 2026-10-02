import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Defines the translations table with fields for input, output, languages, timestamp, and favorite flag.
class Translations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get input => text()();
  TextColumn get output => text()();
  TextColumn get fromLang => text()();
  TextColumn get toLang => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(Constant(false))();
}

/// The main database class, exposing the DAO.
@DriftDatabase(tables: [Translations], daos: [TranslationDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// The one shared connection. History, Favorites and the Document page each
  /// opened (and closed) their own connection to the same file before.
  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 1;

  /// Lazily opens the connection to a file in the app's documents directory.
  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'app.db'));
      return NativeDatabase(file);
    });
  }
}

@DriftAccessor(tables: [Translations])
class TranslationDao extends DatabaseAccessor<AppDatabase>
    with _$TranslationDaoMixin {
  TranslationDao(super.db);

  /// Inserts a new translation record.
  Future<int> insertTranslation(TranslationsCompanion row) =>
      into(translations).insert(row);

  /// Retrieves all translations, newest first.
  Future<List<Translation>> getAll() =>
      (select(translations)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();

  /// Toggles the favorite status on a given record.
  Future<void> toggleFavorite(int id, bool isFav) => (update(translations)
    ..where(
      (t) => t.id.equals(id),
    )).write(TranslationsCompanion(isFavorite: Value(isFav)));

  /// Deletes the translation row with the given [id].
  Future<void> deleteEntry(int id) =>
      (delete(translations)..where((t) => t.id.equals(id))).go();

  /// Deletes every translation (Settings > Clear entire history).
  Future<int> deleteAll() => delete(translations).go();

  /// ✅ Find exact match of input/output
  Future<Translation?> findExactMatch(String input, String output) {
    return (select(translations)
          ..where((t) => t.input.equals(input) & t.output.equals(output))
          ..limit(1))
        .getSingleOrNull();
  }
}
