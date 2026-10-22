/// A calendar day in the device's local time zone, with no time component.
///
/// Intake history is grouped by local day, so this type keeps "which day is it"
/// separate from "which instant is it" and avoids midnight off-by-one bugs.
class LocalDay implements Comparable<LocalDay> {
  LocalDay(int year, int month, int day)
      : _date = DateTime(year, month, day);

  factory LocalDay.fromDateTime(DateTime dt) {
    final local = dt.toLocal();
    return LocalDay(local.year, local.month, local.day);
  }

  /// Parses `yyyy-MM-dd` as written by [key].
  factory LocalDay.parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid day key', key);
    }
    return LocalDay(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  final DateTime _date;

  int get year => _date.year;
  int get month => _date.month;
  int get day => _date.day;

  /// ISO weekday: Monday = 1 ... Sunday = 7.
  int get weekday => _date.weekday;

  /// Local midnight at the start of this day.
  DateTime get start => DateTime(year, month, day);

  /// Local midnight at the start of the next day (exclusive end).
  DateTime get end => DateTime(year, month, day + 1);

  LocalDay addDays(int days) => LocalDay(year, month, day + days);

  /// Stable storage key, e.g. `2026-10-20`.
  String get key =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Sunday of the week containing this day (the prototype's week runs Sun to Sat).
  LocalDay get startOfWeekSunday => addDays(-(weekday % 7));

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  bool isBefore(LocalDay other) => compareTo(other) < 0;
  bool isAfter(LocalDay other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDay other) => _date.compareTo(other._date);

  @override
  bool operator ==(Object other) => other is LocalDay && other._date == _date;

  @override
  int get hashCode => _date.hashCode;

  @override
  String toString() => key;
}
