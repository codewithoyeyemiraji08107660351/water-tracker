import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite file and its schema migrations.
///
/// Add a new migration by bumping [_version] and adding a case to [_migrate].
/// Never edit an existing migration once the app has shipped.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _fileName = 'water_tracker.db';
  static const _version = 1;

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _migrate(db, 0, version),
      onUpgrade: _migrate,
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var v = from + 1; v <= to; v++) {
      switch (v) {
        case 1:
          batch.execute('''
            CREATE TABLE intake_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount_ml INTEGER NOT NULL CHECK (amount_ml > 0 AND amount_ml <= 5000),
              logged_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          batch.execute('CREATE INDEX idx_intake_logged_at ON intake_entries (logged_at)');
          batch.execute('''
            CREATE TABLE reminders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              minute_of_day INTEGER NOT NULL CHECK (minute_of_day BETWEEN 0 AND 1439),
              weekdays INTEGER NOT NULL CHECK (weekdays BETWEEN 0 AND 127),
              enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
              created_at INTEGER NOT NULL,
              UNIQUE (minute_of_day)
            )
          ''');
          // Goal snapshot per day, so changing the goal today does not rewrite
          // the completion % of past days on the History screen.
          batch.execute('''
            CREATE TABLE daily_goals (
              day TEXT PRIMARY KEY,
              goal_ml INTEGER NOT NULL CHECK (goal_ml > 0)
            )
          ''');
      }
    }
    await batch.commit(noResult: true);
  }
}
