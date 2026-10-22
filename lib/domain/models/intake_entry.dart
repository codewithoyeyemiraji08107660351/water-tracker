/// One logged drink.
class IntakeEntry {
  const IntakeEntry({
    required this.id,
    required this.amountMl,
    required this.loggedAt,
  });

  final int id;
  final int amountMl;

  /// The moment the drink was logged (stored as a UTC instant, shown in local time).
  final DateTime loggedAt;

  IntakeEntry copyWith({int? amountMl, DateTime? loggedAt}) => IntakeEntry(
        id: id,
        amountMl: amountMl ?? this.amountMl,
        loggedAt: loggedAt ?? this.loggedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is IntakeEntry && other.id == id && other.amountMl == amountMl && other.loggedAt == loggedAt;

  @override
  int get hashCode => Object.hash(id, amountMl, loggedAt);
}

/// Validation rules shared by the UI and the repository.
abstract final class IntakeRules {
  static const int minMl = 10;
  static const int maxMl = 5000;

  static String? validateAmount(int ml) {
    if (ml < minMl) return 'Enter at least $minMl ml.';
    if (ml > maxMl) return 'That is more than ${maxMl ~/ 1000} litres in one go.';
    return null;
  }
}
