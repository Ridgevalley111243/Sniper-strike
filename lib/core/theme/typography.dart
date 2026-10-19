import 'package:flutter/material.dart';

import 'tokens.dart';

/// The TRUHive type ramp (Montserrat), matching the Figma text styles.
abstract final class AppText {
  static const _family = 'Montserrat';

  static const display = TextStyle(
      fontFamily: _family, fontSize: 34, height: 40 / 34, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const h1 = TextStyle(
      fontFamily: _family, fontSize: 26, height: 32 / 26, fontWeight: FontWeight.w700, letterSpacing: -0.26);
  static const h2 = TextStyle(
      fontFamily: _family, fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  static const h3 = TextStyle(fontFamily: _family, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontFamily: _family, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const bodyMedium =
      TextStyle(fontFamily: _family, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w500);
  static const secondary =
      TextStyle(fontFamily: _family, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const caption = TextStyle(
      fontFamily: _family, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  static const metadata = TextStyle(
      fontFamily: _family, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, letterSpacing: 0.66);
  static const button = TextStyle(fontFamily: _family, fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w600);
  static const nav = TextStyle(fontFamily: _family, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500);
}

extension TextColor on TextStyle {
  TextStyle get primary => copyWith(color: AppColors.textPrimary);
  TextStyle get secondaryColor => copyWith(color: AppColors.textSecondary);
  TextStyle get muted => copyWith(color: AppColors.textMuted);
  TextStyle get onAccent => copyWith(color: AppColors.textOnAccent);
  TextStyle tint(Color c) => copyWith(color: c);
}
