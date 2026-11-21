
import 'dart:math' as math;
import '../models/intake_entry.dart';

/// Thrown when a drink would push a day's total past the daily goal.
class DailyLimitException implements Exception {
  DailyLimitException(this.remainingMl);

  /// How much can still be logged today. 0 means the goal is already reached.
  final int remainingMl;

  bool get goalReached => remainingMl <= 0;

  @override
  String toString() =>
      goalReached ? "Today's goal is already reached." : 'Only $remainingMl ml left for today.';
}

/// Keeps a day's total at or under the daily goal.
///
/// A new drink can only fill what is left of the goal. An existing drink can be
/// edited up to what is left, and can always keep or lower its own amount, so a
/// user who lowers their goal after drinking can still correct today's entries.
abstract final class DailyCap {
  /// What is left to drink today, never negative.
  static int remaining({required int totalMl, required int goalMl}) =>
      math.max(0, goalMl - totalMl);

  /// Largest amount one drink may have. [otherTotalMl] is everything else
  /// logged that day; [currentAmountMl] is the drink's amount before an edit
  /// (null for a new drink).
  static int maxAllowed({required int otherTotalMl, required int goalMl, int? currentAmountMl}) {
    final room = remaining(totalMl: otherTotalMl, goalMl: goalMl);
    return math.min(IntakeRules.maxMl, math.max(room, currentAmountMl ?? 0));
  }

  /// Smallest amount one drink may have. Normally [IntakeRules.minMl], but
  /// lower when less than that is left, so the last few ml can still be logged.
  static int minAllowed(int maxAllowedMl) => math.min(IntakeRules.minMl, maxAllowedMl);

  /// The amount a quick-add button logs: the cup, or what is left if smaller.
  static int topUpAmount({required int cupMl, required int totalMl, required int goalMl}) =>
      math.min(cupMl, remaining(totalMl: totalMl, goalMl: goalMl));
}
