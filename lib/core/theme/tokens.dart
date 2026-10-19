import 'package:flutter/material.dart';

/// Design tokens. These mirror the "TRUHive Tokens" variable collection in the
/// Figma file one-to-one, so design and code share the same names.
abstract final class AppColors {
  // Master palette
  static const navy = Color(0xFF0A1931);
  static const blue = Color(0xFF4A7FA7);
  static const lightBlue = Color(0xFFB3CFE5);
  static const offWhite = Color(0xFFF6FAFD);

  // Semantic
  static const bgPrimary = navy;
  static const surfacePrimary = Color(0xFF102542);
  static const surfaceSecondary = Color(0xFF173454);
  static const surfaceElevated = Color(0xFF1D3E63);
  static const textPrimary = offWhite;
  static const textSecondary = lightBlue;
  static const textMuted = Color(0xFF8EA9BE);
  static const textOnAccent = navy;
  static const accent = lightBlue;
  static const accentStrong = blue;
  static const borderSoft = Color(0x2EB3CFE5); // light-blue @ 18%
  static const borderStrong = Color(0x52B3CFE5); // light-blue @ 32%
  static const scrim = Color(0x99050D1A);
  static const success = Color(0xFF8FD3C1);
  static const error = Color(0xFFE79A9A);
  static const warning = Color(0xFFE8C88F);
  static const deep = Color(0xFF050D1A);
}

abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const x3 = 32.0;
  static const x4 = 40.0;
  static const x5 = 48.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const card = 18.0;
  static const pill = 999.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);
}

abstract final class Breakpoints {
  /// Below this width the app uses the phone layout (bottom nav + mini player).
  static const tablet = 640.0;

  /// At or above this width the app switches to the sidebar + player bar layout.
  static const desktop = 1024.0;

  /// Maximum readable width for single-column content on tablets.
  static const contentMax = 760.0;
}

abstract final class Effects {
  static List<BoxShadow> glow([double opacity = 0.45, double blur = 36]) => [
        BoxShadow(color: AppColors.lightBlue.withValues(alpha: opacity), blurRadius: blur),
      ];

  static const elevation = [
    BoxShadow(color: Color(0x80030A16), offset: Offset(0, 14), blurRadius: 36, spreadRadius: -6),
  ];

  static const soft = [
    BoxShadow(color: Color(0x59030A16), offset: Offset(0, 6), blurRadius: 18, spreadRadius: -4),
  ];
}
