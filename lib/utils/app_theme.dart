import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand palette — matched to the React frontend CSS variables ──
  // primary:  hsl(222 100% 68%) → #5C8DFF  vivid blue
  static const Color primaryColor   = Color(0xFF5C8DFF);

  /// Login / onboarding full-screen backgrounds — Tailwind `from-blue-400 via-blue-500 to-violet-500`
  /// (see Memematestrace `OnboardingScreen.tsx` slide gradients).
  static const Color authGradientStart = Color(0xFF60A5FA); // blue-400
  static const Color authGradientMid = Color(0xFF3B82F6); // blue-500
  static const Color authGradientEnd = Color(0xFF8B5CF6); // violet-500

  /// Tailwind palette — Mercotrace `OnboardingScreen.tsx` / `LoginScreen.tsx`
  static const Color twBlue400 = Color(0xFF60A5FA);
  static const Color twBlue500 = Color(0xFF3B82F6);
  static const Color twBlue600 = Color(0xFF2563EB);
  static const Color twViolet400 = Color(0xFFA78BFA);
  static const Color twViolet500 = Color(0xFF8B5CF6);
  /// `bg-slate-950` under Mercotrace onboarding gradients
  static const Color mercotraceSlate950 = Color(0xFF020617);
  // accent:   hsl(252 100% 69%) → #8161FF  violet-purple
  static const Color secondaryColor = Color(0xFF8161FF);
  // lighter tint of primary for tertiary uses
  static const Color accentColor    = Color(0xFF99BBFF);
  // success:  hsl(152 69%  45%) → #24C278  emerald
  static const Color successColor   = Color(0xFF24C278);
  // error:    hsl(0   72%  55%) → #DF3A3A  red
  static const Color errorColor     = Color(0xFFDF3A3A);
  // warning:  hsl(38  92%  50%) → #F59F0A  amber
  static const Color warningColor   = Color(0xFFF59F0A);
  // info:     hsl(200 80%  50%) → #1AA2E6  cyan-blue
  static const Color infoColor      = Color(0xFF1AA2E6);

  // ── Light mode surfaces ──
  // background: hsl(220 30%  96%) → #F2F4F8
  static const Color _lightBg       = Color(0xFFF2F4F8);
  // card / surface: white
  static const Color _lightSurface  = Color(0xFFFFFFFF);
  // foreground: hsl(220 25%  12%) → #172030
  static const Color _lightFg       = Color(0xFF172030);
  // muted text: hsl(220 15%  40%) → #576175
  static const Color _mutedFg       = Color(0xFF576175);
  // border:     hsl(220 20%  88%) → #DAE0EA
  static const Color _border        = Color(0xFFDAE0EA);

  // ── Dark mode surfaces ──
  // background: hsl(222 47%  11%) → #0F1729
  static const Color _darkBg        = Color(0xFF0F1729);
  // card:       hsl(217 33%  17%) → #1D283A
  static const Color _darkSurface   = Color(0xFF1D283A);
  // muted text: hsl(215 16%  65%) → #9FABC0
  static const Color _darkMutedFg   = Color(0xFF9FABC0);
  // border:     hsl(215 30%  20%) → #2B3D54
  static const Color _darkBorder    = Color(0xFF2B3D54);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      tertiary: successColor,
      onTertiary: Colors.white,
      error: errorColor,
      onError: Colors.white,
      surface: _lightSurface,
      onSurface: _lightFg,
      onSurfaceVariant: _mutedFg,
      outline: _border,
      outlineVariant: Color(0xFFEBEFF6),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _lightBg,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 4,
        color: _lightSurface,
        shadowColor: primaryColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _lightFg,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _lightFg,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightFg,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: _lightFg,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      tertiary: successColor,
      onTertiary: Colors.white,
      error: errorColor,
      onError: Colors.white,
      surface: _darkSurface,
      onSurface: Colors.white,
      onSurfaceVariant: _darkMutedFg,
      outline: _darkBorder,
      outlineVariant: Color(0xFF233347),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBg,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 4,
        color: _darkSurface,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// One Mercotrace onboarding slide: `bg-gradient-to-br` + `bgPattern` (see `OnboardingScreen.tsx`).
class MercotraceOnboardingSlideVisual {
  const MercotraceOnboardingSlideVisual({
    required this.gradient,
    required this.patternCenter,
    required this.patternPeakWhite,
    required this.patternRadius,
  });

  final List<Color> gradient;
  final Alignment patternCenter;
  final double patternPeakWhite;
  final double patternRadius;

  /// Cycles when there are more than four intro pages.
  static const List<MercotraceOnboardingSlideVisual> slides = [
    MercotraceOnboardingSlideVisual(
      gradient: [
        AppTheme.twBlue400,
        AppTheme.twBlue500,
        AppTheme.twViolet500,
      ],
      patternCenter: Alignment(-0.6, 0.6),
      patternPeakWhite: 0.1,
      patternRadius: 0.5,
    ),
    MercotraceOnboardingSlideVisual(
      gradient: [
        AppTheme.twBlue500,
        AppTheme.twViolet500,
        AppTheme.twBlue400,
      ],
      patternCenter: Alignment(0.6, -0.6),
      patternPeakWhite: 0.1,
      patternRadius: 0.5,
    ),
    MercotraceOnboardingSlideVisual(
      gradient: [
        AppTheme.twViolet500,
        AppTheme.twBlue500,
        AppTheme.twViolet400,
      ],
      patternCenter: Alignment.center,
      patternPeakWhite: 0.15,
      patternRadius: 0.6,
    ),
    MercotraceOnboardingSlideVisual(
      gradient: [
        AppTheme.twBlue400,
        AppTheme.twViolet500,
        AppTheme.twBlue500,
      ],
      patternCenter: Alignment(-0.4, 0.4),
      patternPeakWhite: 0.1,
      patternRadius: 0.5,
    ),
  ];
}
