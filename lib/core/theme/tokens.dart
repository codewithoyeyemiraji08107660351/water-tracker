import 'package:flutter/material.dart';

/// Design tokens taken from the Figma prototype. Every color, spacing value,
/// radius and duration in the UI comes from here, never a literal in a widget.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF4DB6F0); // top bar, toggles, bars
  static const primaryDark = Color(0xFF1F8FD1); // pressed / text on light blue
  static const primarySoft = Color(0xFFDDF1FC); // ring track, chips background
  static const accent = Color(0xFF8B5CF6); // current intake number
  static const success = Color(0xFFF2A93B); // goal-met check badge
  static const danger = Color(0xFFE5484D); // delete

  // Neutrals
  static const ink = Color(0xFF1C2430); // primary text
  static const inkMuted = Color(0xFF6B7380); // secondary text
  static const inkFaint = Color(0xFFA3A9B3); // disabled / hints
  static const line = Color(0xFFE3E6EA); // dividers
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEEBEA); // week strip / expanded row
  static const onPrimary = Color(0xFFFFFFFF);

  // Report legend dots (History)
  static const dotGreen = Color(0xFF2E8B3E);
  static const dotNavy = Color(0xFF1E3A8A);
  static const dotOrange = Color(0xFFD9822B);
  static const dotRed = Color(0xFFC0392B);
}

abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 700);
}

abstract final class AppSizes {
  /// Minimum touch target (Material / WCAG guidance).
  static const touchTarget = 48.0;
  static const progressRing = 220.0;
  static const maxContentWidth = 560.0;
}
