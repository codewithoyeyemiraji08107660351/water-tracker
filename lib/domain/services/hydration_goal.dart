import '../models/user_settings.dart';

/// Suggested daily drinking goal.
///
/// With a weight: about 33 ml per kg. Without one: the EFSA adequate intake
/// for total water (2.0 L women, 2.5 L men) minus the ~20% that comes from
/// food. This is a starting point the user can override, not medical advice.
abstract final class HydrationGoal {
  static const int mlPerKg = 33;
  static const int minSuggested = 1200;
  static const int maxSuggested = 4000;

  static int suggestMl({Gender? gender, double? weightKg}) {
    final double raw;
    if (weightKg != null && weightKg > 0) {
      raw = weightKg * mlPerKg;
    } else {
      raw = switch (gender) {
        Gender.female => 1600.0,
        Gender.male => 2000.0,
        Gender.other || null => 1800.0,
      };
    }
    final rounded = (raw / 50).round() * 50;
    return rounded.clamp(minSuggested, maxSuggested);
  }
}
