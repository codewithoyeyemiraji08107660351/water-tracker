import 'package:sqflite/sqflite.dart';

import '../../domain/models/reminder.dart';

class DuplicateReminderException implements Exception {
  @override
  String toString() => 'A reminder already exists at that time.';
}

class ReminderRepository {
  ReminderRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _table = 'reminders';

  Future<List<Reminder>> all() async {
    final rows = await _db.query(_table, orderBy: 'minute_of_day ASC');
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Reminder> add({required int minuteOfDay, Weekdays weekdays = Weekdays.everyday}) async {
    try {
      final id = await _db.insert(
        _table,
        {
          'minute_of_day': minuteOfDay,
          'weekdays': weekdays.mask,
          'enabled': 1,
          'created_at': _now().toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return Reminder(id: id, minuteOfDay: minuteOfDay, weekdays: weekdays, enabled: true);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateReminderException();
      rethrow;
    }
  }

  Future<void> update(Reminder reminder) async {
    try {
      await _db.update(
        _table,
        {
          'minute_of_day': reminder.minuteOfDay,
          'weekdays': reminder.weekdays.mask,
          'enabled': reminder.enabled ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [reminder.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateReminderException();
      rethrow;
    }
  }

  Future<void> delete(int id) => _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  /// Replaces the whole schedule atomically (used by Auto mode).
  Future<void> replaceAll(List<int> minutesOfDay) async {
    final unique = minutesOfDay.toSet().toList()..sort();
    await _db.transaction((txn) async {
      await txn.delete(_table);
      final batch = txn.batch();
      final createdAt = _now().toUtc().millisecondsSinceEpoch;
      for (final minute in unique) {
        batch.insert(_table, {
          'minute_of_day': minute,
          'weekdays': Weekdays.everyday.mask,
          'enabled': 1,
          'created_at': createdAt,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  static Reminder _fromRow(Map<String, Object?> row) => Reminder(
        id: row['id']! as int,
        minuteOfDay: row['minute_of_day']! as int,
        weekdays: Weekdays(row['weekdays']! as int),
        enabled: (row['enabled']! as int) == 1,
      );
}
