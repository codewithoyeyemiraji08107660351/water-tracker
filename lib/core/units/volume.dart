/// Measurement system chosen in Settings. Data is always stored in ml and kg;
/// this only changes what the user sees and types.
enum UnitSystem {
  metric('kg, ml'),
  imperial('lb, fl oz');

  const UnitSystem(this.label);
  final String label;
}

abstract final class Volume {
  static const double mlPerFlOz = 29.5735;
  static const double kgPerLb = 0.45359237;

  /// Converts a stored ml value into the display unit.
  static double fromMl(int ml, UnitSystem unit) =>
      unit == UnitSystem.metric ? ml.toDouble() : ml / mlPerFlOz;

  /// Converts a value typed in the display unit back to ml.
  static int toMl(double value, UnitSystem unit) =>
      unit == UnitSystem.metric ? value.round() : (value * mlPerFlOz).round();

  static String unitLabel(UnitSystem unit) => unit == UnitSystem.metric ? 'ml' : 'fl oz';

  /// "200 ml" or "6.8 fl oz".
  static String format(int ml, UnitSystem unit, {bool withUnit = true}) {
    final value = fromMl(ml, unit);
    final number = unit == UnitSystem.metric
        ? value.round().toString()
        : (value >= 100 ? value.round().toString() : value.toStringAsFixed(1));
    return withUnit ? '$number ${unitLabel(unit)}' : number;
  }

  static double weightFromKg(double kg, UnitSystem unit) =>
      unit == UnitSystem.metric ? kg : kg / kgPerLb;

  static double weightToKg(double value, UnitSystem unit) =>
      unit == UnitSystem.metric ? value : value * kgPerLb;

  static String weightUnitLabel(UnitSystem unit) => unit == UnitSystem.metric ? 'kg' : 'lb';
}
