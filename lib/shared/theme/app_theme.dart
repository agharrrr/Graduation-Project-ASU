import 'package:flutter/material.dart';
import '../../Auth/app_role.dart';

class AppTheme {
  AppTheme._();

  // Legacy helpers (so old code like AppTheme.user() compiles)
  static ThemeData user() => build(role: AppRole.user, mode: ThemeMode.dark);
  static ThemeData organizer() => build(role: AppRole.organizer, mode: ThemeMode.dark);
  static ThemeData admin() => build(role: AppRole.admin, mode: ThemeMode.dark);

  static ThemeData build({required AppRole role, required ThemeMode mode}) {
    final bool isDark = mode == ThemeMode.dark;

    final _Variant v = switch (role) {
      AppRole.organizer => isDark ? _Variant.organizerDark() : _Variant.organizerLight(),
      AppRole.admin => isDark ? _Variant.adminDark() : _Variant.adminLight(),
      _ => isDark ? _Variant.userDark() : _Variant.userLight(),
    };

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,

      primary: v.primary,
      onPrimary: v.onPrimary,
      primaryContainer: v.primaryContainer,
      onPrimaryContainer: v.onPrimaryContainer,

      secondary: v.secondary,
      onSecondary: v.onSecondary,
      secondaryContainer: v.secondaryContainer,
      onSecondaryContainer: v.onSecondaryContainer,

      tertiary: v.tertiary,
      onTertiary: v.onTertiary,
      tertiaryContainer: v.tertiaryContainer,
      onTertiaryContainer: v.onTertiaryContainer,

      background: v.background,
      onBackground: v.onSurface,

      surface: v.surface,
      onSurface: v.onSurface,

      surfaceVariant: v.surface2,
      onSurfaceVariant: v.onSurfaceMuted,

      error: const Color(0xFFB91C1C),
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3B0A0A) : const Color(0xFFFEE2E2),
      onErrorContainer: isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D),

      outline: v.border,
      outlineVariant: v.border.withValues(alpha: 0.55),

      shadow: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
      scrim: Colors.black.withValues(alpha: isDark ? 0.55 : 0.40),

      inverseSurface: isDark ? const Color(0xFFF0F2F7) : const Color(0xFF0B1220),
      onInverseSurface: isDark ? const Color(0xFF0B1220) : Colors.white,
      inversePrimary: v.primary,
    );

    const double cardRadius = 16;
    const double inputRadius = 14;
    const double buttonRadius = 14;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ✅ This is what removes “white screens”
      scaffoldBackgroundColor: v.background,
      canvasColor: v.background,

      textTheme: TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: v.onSurface),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: v.onSurface),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: v.onSurface),
        bodyMedium: TextStyle(fontSize: 15, color: v.onSurface),
        bodySmall: TextStyle(fontSize: 13, color: v.onSurfaceMuted),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: v.background,
        foregroundColor: v.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: v.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),

      cardTheme: CardThemeData(
        color: v.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: v.border.withValues(alpha: 0.70)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: v.border.withValues(alpha: 0.70),
        thickness: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: v.surface,
        labelStyle: TextStyle(color: v.onSurfaceMuted),
        hintStyle: TextStyle(color: v.onSurfaceMuted),
        prefixIconColor: v.onSurfaceMuted,
        suffixIconColor: v.onSurfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: v.border.withValues(alpha: 0.70)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: v.border.withValues(alpha: 0.70)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: v.primary, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: v.primary,
          foregroundColor: v.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: v.primary,
          foregroundColor: v.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: v.onSurface,
          side: BorderSide(color: v.border.withValues(alpha: 0.80)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: v.surface2,
        selectedColor: v.primaryContainer,
        labelStyle: TextStyle(color: v.onSurface),
        side: BorderSide(color: v.border.withValues(alpha: 0.70)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: v.surface,
        indicatorColor: v.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: v.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: v.onSurfaceMuted),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: v.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: TextStyle(
          color: v.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: v.onSurfaceMuted,
          fontSize: 14,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: v.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: v.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: v.onSurface,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Theme Variants
// -----------------------------------------------------------------------------
class _Variant {
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;

  final Color primary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  final Color onSurface;
  final Color onSurfaceMuted;

  final Color onPrimary;
  final Color onSecondary;
  final Color onTertiary;

  _Variant({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onPrimary,
    required this.onSecondary,
    required this.onTertiary,
  });

  // ---------------- USER ----------------
  factory _Variant.userLight() => _Variant(
    background: const Color(0xFFF3F6FF),
    surface: const Color(0xFFF8FAFF),
    surface2: const Color(0xFFEAF0FF),
    border: const Color(0xFFCBD5FF),

    primary: const Color(0xFF5B7CFF),
    primaryContainer: const Color(0xFFDCE6FF),
    onPrimaryContainer: const Color(0xFF0B1220),

    secondary: const Color(0xFF7C5CFF),
    secondaryContainer: const Color(0xFFE8E1FF),
    onSecondaryContainer: const Color(0xFF0B1220),

    tertiary: const Color(0xFF3B82F6),
    tertiaryContainer: const Color(0xFFD7E8FF),
    onTertiaryContainer: const Color(0xFF0B1220),

    onSurface: const Color(0xFF0B1220),
    onSurfaceMuted: const Color(0xFF5B6478),

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
  );

  // ✅ Non-white default (dark)
  factory _Variant.userDark() => _Variant(
    background: const Color(0xFF0B1220),
    surface: const Color(0xFF111B2E),
    surface2: const Color(0xFF16233B),
    border: const Color(0xFF27314A),

    primary: const Color(0xFF5B7CFF),
    primaryContainer: const Color(0xFF1D2B4D),
    onPrimaryContainer: const Color(0xFFEAF0FF),

    secondary: const Color(0xFF7C5CFF),
    secondaryContainer: const Color(0xFF2A1F4C),
    onSecondaryContainer: const Color(0xFFF1ECFF),

    tertiary: const Color(0xFF3B82F6),
    tertiaryContainer: const Color(0xFF183457),
    onTertiaryContainer: const Color(0xFFE6F0FF),

    onSurface: const Color(0xFFF2F5FF),
    onSurfaceMuted: const Color(0xFFB7C0D6),

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
  );

  // ---------------- ORGANIZER ----------------
  factory _Variant.organizerLight() => _Variant(
    background: const Color(0xFFF2FBFA),
    surface: const Color(0xFFF8FEFD),
    surface2: const Color(0xFFE6FAF6),
    border: const Color(0xFFBFEDE4),

    primary: const Color(0xFF14B8A6),
    primaryContainer: const Color(0xFFD1FAF5),
    onPrimaryContainer: const Color(0xFF06201C),

    secondary: const Color(0xFF0EA5E9),
    secondaryContainer: const Color(0xFFD6F1FF),
    onSecondaryContainer: const Color(0xFF061B25),

    tertiary: const Color(0xFF22C55E),
    tertiaryContainer: const Color(0xFFDDFBE7),
    onTertiaryContainer: const Color(0xFF072014),

    onSurface: const Color(0xFF061B25),
    onSurfaceMuted: const Color(0xFF4E6B73),

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
  );

  factory _Variant.organizerDark() => _Variant(
    background: const Color(0xFF071A1A),
    surface: const Color(0xFF0B2322),
    surface2: const Color(0xFF103332),
    border: const Color(0xFF1E4A47),

    primary: const Color(0xFF14B8A6),
    primaryContainer: const Color(0xFF0E3A36),
    onPrimaryContainer: const Color(0xFFD1FAF5),

    secondary: const Color(0xFF0EA5E9),
    secondaryContainer: const Color(0xFF0A2B3A),
    onSecondaryContainer: const Color(0xFFD6F1FF),

    tertiary: const Color(0xFF22C55E),
    tertiaryContainer: const Color(0xFF0D2E1A),
    onTertiaryContainer: const Color(0xFFDDFBE7),

    onSurface: const Color(0xFFEAFDFB),
    onSurfaceMuted: const Color(0xFFB7D7D2),

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
  );

  // ---------------- ADMIN ----------------
  factory _Variant.adminLight() => _Variant(
    background: const Color(0xFFF5F5F7),
    surface: Colors.white,
    surface2: const Color(0xFFF0F1F5),
    border: const Color(0xFFD7DAE5),

    primary: const Color(0xFF0B5FFF),
    primaryContainer: const Color(0xFFD6E4FF),
    onPrimaryContainer: const Color(0xFF0B1220),

    secondary: const Color(0xFF111827),
    secondaryContainer: const Color(0xFFE5E7EB),
    onSecondaryContainer: const Color(0xFF0B1220),

    tertiary: const Color(0xFFD4AF37),
    tertiaryContainer: const Color(0xFFFFF0C2),
    onTertiaryContainer: const Color(0xFF1F1400),

    onSurface: const Color(0xFF0B1220),
    onSurfaceMuted: const Color(0xFF6B7280),

    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: const Color(0xFF1F1400),
  );

  factory _Variant.adminDark() => _Variant(
    background: const Color(0xFF0C0F16),
    surface: const Color(0xFF121826),
    surface2: const Color(0xFF161E2F),
    border: const Color(0xFF283044),

    primary: const Color(0xFF0B5FFF),
    primaryContainer: const Color(0xFF182C57),
    onPrimaryContainer: const Color(0xFFD6E4FF),

    secondary: const Color(0xFFE5E7EB),
    secondaryContainer: const Color(0xFF2A3246),
    onSecondaryContainer: const Color(0xFFE5E7EB),

    tertiary: const Color(0xFFD4AF37),
    tertiaryContainer: const Color(0xFF3A2F10),
    onTertiaryContainer: const Color(0xFFFFF0C2),

    onSurface: const Color(0xFFF2F3F7),
    onSurfaceMuted: const Color(0xFFB3B7C3),

    onPrimary: Colors.white,
    onSecondary: const Color(0xFF0B1220),
    onTertiary: const Color(0xFF1F1400),
  );
}
