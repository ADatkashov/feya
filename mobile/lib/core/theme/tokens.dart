import 'package:flutter/material.dart';

/// FEYA design tokens. Use these instead of scattering colors, radii or spacing through widgets.
class FeyaColors {
  FeyaColors._();

  static const bg = Color(0xFF080910);
  static const surface = Color(0xFF12131D);
  static const surface2 = Color(0xFF1B1C28);
  static const primary = Color(0xFFF04493);
  static const secondary = Color(0xFFD957AE);
  static const text = Color(0xFFF8F5F8);
  static const textSecondary = Color(0xFFAAA7B5);
  static const border = Color(0xFF302536);
  static const success = Color(0xFF3DD68C);
  static const error = Color(0xFFFF6B86);
  static const warning = Color(0xFFFFB84D);

  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, secondary],
  );

  static const softGlow = [
    BoxShadow(
      color: Color(0x55F04493),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];
}

class FeyaSpace {
  FeyaSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 16; // horizontal screen gutter
}

class FeyaRadius {
  FeyaRadius._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
  static BorderRadius get card => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
}
