import 'package:flutter/material.dart';

/// Formatting helpers that respect the device's 12/24-hour preference.
abstract final class TimeFormat {
  static String timeOfDay(BuildContext context, TimeOfDay time) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    return MaterialLocalizations.of(context).formatTimeOfDay(time, alwaysUse24HourFormat: use24h);
  }

  static String dateTime(BuildContext context, DateTime dt) =>
      timeOfDay(context, TimeOfDay.fromDateTime(dt));

  static String minuteOfDay(BuildContext context, int minuteOfDay) =>
      timeOfDay(context, TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60));

  static const monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const monthLong = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Sunday-first labels to match the prototype's week strip.
  static const weekdayShortSunFirst = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const weekdayLetterSunFirst = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
}
