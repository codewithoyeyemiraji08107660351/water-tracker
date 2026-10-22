import 'package:sqflite/sqflite.dart';

import '../../core/time/local_day.dart';

/// Stores the goal that applied on each day, so past completion stays accurate
/// after the user changes their goal.
class GoalRepository {
  GoalRepository(this._db);

  final Database _db;
  static const _table = 'daily_goals';

  Future<void> setGoalForDay(LocalDay day, int goalMl) => _db.insert(
        _table,
        {'day': day.key, 'goal_ml': goalMl},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Goals for `from <= day <= to`, keyed by [LocalDay.key].
  Future<Map<String, int>> goalsBetween(LocalDay from, LocalDay to) async {
    final rows = await _db.query(
      _table,
      where: 'day >= ? AND day <= ?',
      whereArgs: [from.key, to.key],
    );
    return {for (final r in rows) r['day']! as String: r['goal_ml']! as int};
  }
}
