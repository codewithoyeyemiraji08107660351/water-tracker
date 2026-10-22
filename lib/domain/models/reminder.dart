/// A set of weekdays stored as a 7-bit mask.
///
/// Bit 0 = Monday ... bit 6 = Sunday, matching [DateTime.weekday] - 1.
class Weekdays {
  const Weekdays(this.mask) : assert(mask >= 0 && mask <= 127);

  static const Weekdays everyday = Weekdays(127);
  static const Weekdays none = Weekdays(0);

  final int mask;

  /// [weekday] uses ISO numbering: Monday = 1 ... Sunday = 7.
  bool contains(int weekday) => mask & (1 << (weekday - 1)) != 0;

  Weekdays toggle(int weekday) => Weekdays(mask ^ (1 << (weekday - 1)));

  bool get isEveryday => mask == 127;
  bool get isEmpty => mask == 0;

  /// ISO weekdays in this set, Monday first.
  List<int> get days => [for (var d = 1; d <= 7; d++) if (contains(d)) d];

  /// "Everyday", "Weekdays", "Weekends" or "Mon, Wed, Fri".
  String describe() {
    if (isEveryday) return 'Everyday';
    if (isEmpty) return 'Never';
    if (mask == 31) return 'Weekdays';
    if (mask == 96) return 'Weekends';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => names[d - 1]).join(', ');
  }

  @override
  bool operator ==(Object other) => other is Weekdays && other.mask == mask;

  @override
  int get hashCode => mask.hashCode;
}

/// A daily reminder slot shown on the Reminder schedule screen.
class Reminder {
  const Reminder({
    required this.id,
    required this.minuteOfDay,
    required this.weekdays,
    required this.enabled,
  }) : assert(minuteOfDay >= 0 && minuteOfDay < 1440);

  final int id;

  /// Minutes after local midnight, e.g. 06:30 = 390.
  final int minuteOfDay;
  final Weekdays weekdays;
  final bool enabled;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  /// True when this reminder can produce a notification at all.
  bool get isActive => enabled && !weekdays.isEmpty;

  Reminder copyWith({int? minuteOfDay, Weekdays? weekdays, bool? enabled}) => Reminder(
        id: id,
        minuteOfDay: minuteOfDay ?? this.minuteOfDay,
        weekdays: weekdays ?? this.weekdays,
        enabled: enabled ?? this.enabled,
      );

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.minuteOfDay == minuteOfDay &&
      other.weekdays == weekdays &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, minuteOfDay, weekdays, enabled);
}
