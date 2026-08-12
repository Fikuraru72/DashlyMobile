import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Extension to easily access colors ---
extension ThemeContext on BuildContext {
  DashlyColors get dashlyColors => Theme.of(this).extension<DashlyColors>()!;
}

class DashlyColors extends ThemeExtension<DashlyColors> {
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color accent;
  final Color accentDim;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color error;
  final Color divider;
  final LinearGradient accentGradient;
  final LinearGradient cardGradient;

  const DashlyColors({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.accent,
    required this.accentDim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.error,
    required this.divider,
    required this.accentGradient,
    required this.cardGradient,
  });

  @override
  ThemeExtension<DashlyColors> copyWith() => this;

  @override
  ThemeExtension<DashlyColors> lerp(ThemeExtension<DashlyColors>? other, double t) {
    if (other is! DashlyColors) return this;
    return DashlyColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accentGradient: other.accentGradient,
      cardGradient: other.cardGradient,
    );
  }
}

class DashlyTheme {
  DashlyTheme._();

  // ─── Shared Constants ──────────────────────────────────────
  static const Color accent = Color(0xFF4CB9E7);
  static const Color errorObj = Color(0xFFFF4C4C);

  // ─── Shadows & Radii ──────────────────────────────────────
  static List<BoxShadow> glowShadow({Color? color, double blur = 20}) => [
        BoxShadow(
          color: (color ?? accent).withValues(alpha: 0.3),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ];

  static final BorderRadius radiusSm = BorderRadius.circular(8);
  static final BorderRadius radiusMd = BorderRadius.circular(12);
  static final BorderRadius radiusLg = BorderRadius.circular(16);
  static final BorderRadius radiusXl = BorderRadius.circular(24);

  // ─── Theme Data ───────────────────────────────────────────
  static ThemeData get lightTheme {
    final colors = DashlyColors(
      background: const Color(0xFFF5F6FA),
      surface: const Color(0xFFFFFFFF),
      surfaceLight: const Color(0xFFE4E6EB),
      accent: const Color(0xFF359ED0),
      accentDim: const Color(0xFF2682AF),
      textPrimary: const Color(0xFF1C1E21),
      textSecondary: const Color(0xFF606770),
      textHint: const Color(0xFF8D949E),
      error: errorObj,
      divider: const Color(0xFFCED0D4),
      accentGradient: const LinearGradient(
        colors: [Color(0xFF4CB9E7), Color(0xFF2B97C6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      cardGradient: const LinearGradient(
        colors: [Color(0xFFE9EFFF), Color(0xFFFFFFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    return _buildTheme(colors, Brightness.light);
  }

  static ThemeData get darkTheme {
    final colors = DashlyColors(
      background: const Color(0xFF121212),
      surface: const Color(0xFF1E1E1E),
      surfaceLight: const Color(0xFF2A2A2A),
      accent: accent,
      accentDim: const Color(0xFF389BCA),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xFFB0B0B0),
      textHint: const Color(0xFF757575),
      error: errorObj,
      divider: const Color(0xFF333333),
      accentGradient: const LinearGradient(
        colors: [Color(0xFF4CB9E7), Color(0xFF2B97C6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      cardGradient: const LinearGradient(
        colors: [Color(0xFF1E1E1E), Color(0xFF252525)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    return _buildTheme(colors, Brightness.dark);
  }

  static ThemeData _buildTheme(DashlyColors ext, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: ext.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: ext.accent,
        onPrimary: Colors.white,
        secondary: ext.accentDim,
        onSecondary: Colors.white,
        error: ext.error,
        onError: Colors.white,
        surface: ext.surface,
        onSurface: ext.textPrimary,
      ),
      extensions: [ext],
      textTheme: GoogleFonts.interTextTheme(
        brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).apply(bodyColor: ext.textPrimary, displayColor: ext.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: ext.textPrimary),
        iconTheme: IconThemeData(color: ext.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ext.accent,
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ext.accent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          side: BorderSide(color: ext.accent, width: 1.5),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ext.accent,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.surfaceLight,
        labelStyle: TextStyle(color: ext.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: ext.textHint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: ext.divider, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: ext.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: ext.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide(color: ext.error, width: 1.5)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ext.surface,
        contentTextStyle: GoogleFonts.inter(color: ext.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ext.accent),
    );
  }

  // Fallback for screens without easy context access
  static InputDecoration inputDecoration(BuildContext context, {required String label, String? hint, IconData? prefixIcon, Widget? suffixIcon}) {
    final ext = context.dashlyColors;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: ext.textSecondary, size: 20) : null,
      suffixIcon: suffixIcon,
    );
  }
}
