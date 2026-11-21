import 'package:sqflite/sqflite.dart';

import '../../core/time/local_day.dart';
import '../../domain/models/intake_entry.dart';
import '../../domain/services/daily_cap.dart';

class IntakeValidationException implements Exception {
  IntakeValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads and writes logged drinks.
///
/// Every write that adds water runs the daily cap check and the write in one
/// transaction, so two fast taps cannot push a day past its goal.
class IntakeRepository {
  IntakeRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _table = 'intake_entries';

  /// Logs a drink. With [topUp], an amount larger than what is left is reduced
  /// to exactly what is left; without it, such an amount is refused.
  Future<IntakeEntry> add({
    required int amountMl,
    required DateTime loggedAt,
    required int dailyGoalMl,
    bool topUp = false,
  }) {
    _validateTime(loggedAt);
    return _db.transaction((txn) async {
      final other = await _dayTotal(txn, LocalDay.fromDateTime(loggedAt));
      final max = DailyCap.maxAllowed(otherTotalMl: other, goalMl: dailyGoalMl);
      final amount = topUp && amountMl > max ? max : amountMl;
      _validateAmount(amount, max);

      final id = await txn.insert(_table, {
        'amount_ml': amount,
        'logged_at': loggedAt.toUtc().millisecondsSinceEpoch,
        'created_at': _now().toUtc().millisecondsSinceEpoch,
      });
      return IntakeEntry(id: id, amountMl: amount, loggedAt: loggedAt);
    });
  }

  /// Re-inserts a deleted entry with its original id (used by "Undo").
  /// Refused if another drink has since filled the room it took.
  Future<void> restore(IntakeEntry entry, {required int dailyGoalMl}) {
    return _db.transaction((txn) async {
      final other = await _dayTotal(txn, LocalDay.fromDateTime(entry.loggedAt), excludeId: entry.id);
      final max = DailyCap.maxAllowed(otherTotalMl: other, goalMl: dailyGoalMl);
      _validateAmount(entry.amountMl, max);

      await txn.insert(
        _table,
        {
          'id': entry.id,
          'amount_ml': entry.amountMl,
          'logged_at': entry.loggedAt.toUtc().millisecondsSinceEpoch,
          'created_at': _now().toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> update(IntakeEntry entry, {required int dailyGoalMl}) {
    _validateTime(entry.loggedAt);
    return _db.transaction((txn) async {
      final rows = await txn.query(_table, columns: ['amount_ml'], where: 'id = ?', whereArgs: [entry.id]);
      if (rows.isEmpty) throw IntakeValidationException('That drink no longer exists.');

      final other = await _dayTotal(txn, LocalDay.fromDateTime(entry.loggedAt), excludeId: entry.id);
      final max = DailyCap.maxAllowed(
        otherTotalMl: other,
        goalMl: dailyGoalMl,
        currentAmountMl: rows.first['amount_ml']! as int,
      );
      _validateAmount(entry.amountMl, max);

      await txn.update(
        _table,
        {
          'amount_ml': entry.amountMl,
          'logged_at': entry.loggedAt.toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    });
  }

  Future<void> delete(int id) => _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  /// Entries with `start <= loggedAt < end`, newest first.
  Future<List<IntakeEntry>> between(DateTime start, DateTime end) async {
    final rows = await _db.query(
      _table,
      columns: ['id', 'amount_ml', 'logged_at'],
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toUtc().millisecondsSinceEpoch, end.toUtc().millisecondsSinceEpoch],
      orderBy: 'logged_at DESC, id DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<List<IntakeEntry>> forDay(LocalDay day) => between(day.start, day.end);

  /// The local day of the very first logged drink, or null if nothing was logged yet.
  Future<LocalDay?> firstDay() async {
    final rows = await _db.rawQuery('SELECT MIN(logged_at) AS first FROM $_table');
    final first = rows.first['first'] as int?;
    if (first == null) return null;
    return LocalDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(first, isUtc: true));
  }

  /// Total ml logged on [day], leaving out the entry [excludeId].
  Future<int> _dayTotal(DatabaseExecutor db, LocalDay day, {int? excludeId}) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_ml), 0) AS total FROM $_table '
      'WHERE logged_at >= ? AND logged_at < ?${excludeId == null ? '' : ' AND id != ?'}',
      [
        day.start.toUtc().millisecondsSinceEpoch,
        day.end.toUtc().millisecondsSinceEpoch,
        if (excludeId != null) excludeId,
      ],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  void _validateAmount(int amountMl, int maxMl) {
    if (amountMl > IntakeRules.maxMl) {
      throw IntakeValidationException(IntakeRules.validateAmount(amountMl)!);
    }
    if (maxMl <= 0 || amountMl > maxMl) {
      throw DailyLimitException(maxMl);
    }
    final min = DailyCap.minAllowed(maxMl);
    if (amountMl < min) throw IntakeValidationException('Enter at least $min ml.');
  }

  void _validateTime(DateTime loggedAt) {
    // Allow small clock drift, but not drinks logged in the future.
    if (loggedAt.isAfter(_now().add(const Duration(minutes: 1)))) {
      throw IntakeValidationException('A drink cannot be logged in the future.');
    }
  }

  static IntakeEntry _fromRow(Map<String, Object?> row) => IntakeEntry(
        id: row['id']! as int,
        amountMl: row['amount_ml']! as int,
        loggedAt: DateTime.fromMillisecondsSinceEpoch(row['logged_at']! as int, isUtc: true).toLocal(),
      );
}
