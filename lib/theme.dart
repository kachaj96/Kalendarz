import 'package:flutter/material.dart';

/// Wersja A z makiety: spokojny, jasny, indygo jako kolor główny.
class AppTheme {
  static const _lightPrimary = Color(0xFF3454D1);
  static const _darkPrimary = Color(0xFF93A5FF);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _lightPrimary,
      surface: Colors.white,
      surfaceContainerLowest: const Color(0xFFF5F6FA),
    ),
    const Color(0xFFF5F6FA),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _darkPrimary,
      onPrimary: const Color(0xFF0E1330),
      surface: const Color(0xFF1A1F2F),
      surfaceContainerLowest: const Color(0xFF10131E),
    ),
    const Color(0xFF10131E),
  );

  static ThemeData _build(ColorScheme scheme, Color background) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Figtree',
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Figtree',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Figtree',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Figtree',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Kolory kategorii (te same co w makiecie, białe napisy mają na nich kontrast).
class CategoryColors {
  static const dom = Color(0xFF12808A);
  static const praca = Color(0xFF2F6FDE);
  static const zakupy = Color(0xFFC75F00);
  static const zdrowie = Color(0xFFD13438);
  static const sport = Color(0xFF5E8C0A);
  static const rodzina = Color(0xFF7B4FD0);
  static const finanse = Color(0xFF1F8A4C);
  static const inne = Color(0xFF5F6B80);
  static const niespodzianki = Color(0xFFC42B8A);
}
