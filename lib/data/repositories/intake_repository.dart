import 'package:sqflite/sqflite.dart';

import '../../core/time/local_day.dart';
import '../../domain/models/intake_entry.dart';

class IntakeValidationException implements Exception {
  IntakeValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads and writes logged drinks.
class IntakeRepository {
  IntakeRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _table = 'intake_entries';

  Future<IntakeEntry> add({required int amountMl, required DateTime loggedAt}) async {
    _validate(amountMl, loggedAt);
    final id = await _db.insert(_table, {
      'amount_ml': amountMl,
      'logged_at': loggedAt.toUtc().millisecondsSinceEpoch,
      'created_at': _now().toUtc().millisecondsSinceEpoch,
    });
    return IntakeEntry(id: id, amountMl: amountMl, loggedAt: loggedAt);
  }

  /// Re-inserts a deleted entry with its original id (used by "Undo").
  Future<void> restore(IntakeEntry entry) async {
    await _db.insert(
      _table,
      {
        'id': entry.id,
        'amount_ml': entry.amountMl,
        'logged_at': entry.loggedAt.toUtc().millisecondsSinceEpoch,
        'created_at': _now().toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(IntakeEntry entry) async {
    _validate(entry.amountMl, entry.loggedAt);
    final count = await _db.update(
      _table,
      {
        'amount_ml': entry.amountMl,
        'logged_at': entry.loggedAt.toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    if (count == 0) {
      throw IntakeValidationException('That drink no longer exists.');
    }
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

  void _validate(int amountMl, DateTime loggedAt) {
    final amountError = IntakeRules.validateAmount(amountMl);
    if (amountError != null) throw IntakeValidationException(amountError);
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
