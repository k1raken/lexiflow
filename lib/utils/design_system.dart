// lib/utils/design_system.dart
// Modern WordFlow Design System

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Colors (LexiFlow Turquoise Brand)
  static const Color primary = Color(0xFF33C4B3); // LexiFlow Primary
  static const Color primaryLight = Color(0xFF70E1F5); // Lighter Turquoise
  static const Color primaryDark = Color(0xFF005F5A); // Darker Turquoise

  // Secondary Colors
  static const Color secondary = Color(0xFF2DD4BF); // LexiFlow Secondary
  static const Color secondaryLight = Color(0xFF6BE8D8); // Lighter Secondary
  static const Color accent = Color(0xFF30C6D9); // LexiFlow Accent

  // Status Colors
  static const Color success = Color(0xFF06D6A0); // Green
  static const Color error = Color(0xFFEF476F); // Red
  static const Color warning = Color(0xFFFFD166); // Yellow
  static const Color info = Color(0xFF3B82F6); // Blue

  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B); // Dark Slate
  static const Color textSecondary = Color(0xFF64748B); // Slate
  static const Color textTertiary = Color(0xFF94A3B8); // Light Slate

  // Background Colors
  static const Color background = Color(0xFFF8FAFC); // Light Gray
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Surface Variant

  // Border Colors
  static const Color border = Color(0xFFE2E8F0); // Border
  static const Color borderLight = Color(0xFFF1F5F9); // Light Border

  // Gradient Colors
  static const List<Color> primaryGradient = [primary, primaryLight];
  static const List<Color> successGradient = [success, secondaryLight];
  static const List<Color> surfaceGradient = [surface, surfaceVariant];
}

// Dark Mode Colors
class AppDarkColors {
  // Primary Colors
  static const Color primary = Color(0xFF33C4B3); // LexiFlow Primary
  static const Color primaryLight = Color(0xFF70E1F5); // Lighter Turquoise
  static const Color primaryDark = Color(0xFF005F5A); // Darker Turquoise

  // Secondary Colors
  static const Color secondary = Color(0xFF2DD4BF); // LexiFlow Secondary
  static const Color secondaryLight = Color(0xFF00524D); // Darker Secondary for Dark Mode

  // Status Colors
  static const Color success = Color(0xFF4ECDC4); // Teal
  static const Color error = Color(0xFFEF476F); // Red
  static const Color warning = Color(0xFFFFD166); // Yellow
  static const Color info = Color(0xFF3B82F6); // Blue

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB0B0B0); // Light Gray
  static const Color textTertiary = Color(0xFF808080); // Medium Gray

  // Background Colors
  static const Color background = Color(0xFF121212); // Dark Background
  static const Color surface = Color(0xFF1E1E1E); // Dark Surface
  static const Color surfaceVariant = Color(0xFF2D2D2D); // Dark Surface Variant

  // Border Colors
  static const Color border = Color(0xFF404040); // Dark Border
  static const Color borderLight = Color(0xFF2D2D2D); // Light Dark Border

  // Gradient Colors
  static const List<Color> primaryGradient = [primary, primaryLight];
  static const List<Color> successGradient = [success, secondaryLight];
  static const List<Color> surfaceGradient = [surface, surfaceVariant];
}

class AppTextStyles {
  // Headlines
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // Titles
  static const TextStyle title1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle title3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Body Text
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle body3 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Button Text
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
    height: 1.2,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
    height: 1.2,
  );
}

class AppShadows {
  static const BoxShadow small = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );

  static const BoxShadow medium = BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BoxShadow large = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static const BoxShadow xlarge = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // Colored shadows
  static BoxShadow primary(Color color) => BoxShadow(
    color: color.withOpacity(0.2),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static BoxShadow success(Color color) => BoxShadow(
    color: color.withOpacity(0.2),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
}

class AppBorderRadius {
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(16));
  static const BorderRadius xlarge = BorderRadius.all(Radius.circular(24));
  static const BorderRadius circular = BorderRadius.all(Radius.circular(999));
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  
  // Screen Padding
  static const double screenPadding = 24.0;
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.primaryGradient,
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.successGradient,
  );

  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.surfaceGradient,
  );

  static const LinearGradient shimmer = LinearGradient(
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
    colors: [Color(0xFFE2E8F0), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    stops: [0.0, 0.5, 1.0],
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: AppColors.surface,
        onSecondary: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onError: AppColors.surface,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.headline1,
        displayMedium: AppTextStyles.headline2,
        displaySmall: AppTextStyles.headline3,
        headlineLarge: AppTextStyles.title1,
        headlineMedium: AppTextStyles.title2,
        headlineSmall: AppTextStyles.title3,
        bodyLarge: AppTextStyles.body1,
        bodyMedium: AppTextStyles.body2,
        bodySmall: AppTextStyles.body3,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.buttonSmall,
        labelSmall: AppTextStyles.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.large,
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppDarkColors.primary,
        brightness: Brightness.dark,
        primary: AppDarkColors.primary,
        secondary: AppDarkColors.secondary,
        surface: AppDarkColors.surface,
        background: AppDarkColors.background,
        error: AppDarkColors.error,
        onPrimary: AppDarkColors.textPrimary,
        onSecondary: AppDarkColors.textPrimary,
        onSurface: AppDarkColors.textPrimary,
        onBackground: AppDarkColors.textPrimary,
        onError: AppDarkColors.textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.headline1,
        displayMedium: AppTextStyles.headline2,
        displaySmall: AppTextStyles.headline3,
        headlineLarge: AppTextStyles.title1,
        headlineMedium: AppTextStyles.title2,
        headlineSmall: AppTextStyles.title3,
        bodyLarge: AppTextStyles.body1,
        bodyMedium: AppTextStyles.body2,
        bodySmall: AppTextStyles.body3,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.buttonSmall,
        labelSmall: AppTextStyles.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDarkColors.primary,
          foregroundColor: AppDarkColors.textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.medium),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.large,
          side: const BorderSide(color: AppDarkColors.borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDarkColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: const BorderSide(color: AppDarkColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: const BorderSide(color: AppDarkColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.medium,
          borderSide: const BorderSide(color: AppDarkColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

// Modern Card Widget
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final List<BoxShadow>? shadows;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool showBorder;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.shadows,
    this.borderRadius,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: borderRadius ?? AppBorderRadius.large,
        border:
            showBorder
                ? Border.all(color: AppColors.borderLight, width: 1)
                : null,
        boxShadow: shadows ?? [AppShadows.medium],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? AppBorderRadius.large,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Modern Button Widget
class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double? height;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: width,
      height: height ?? 48,
      child:
          isOutlined
              ? OutlinedButton(
                onPressed: isEnabled ? onPressed : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor ?? AppColors.primary,
                  side: BorderSide(
                    color: isEnabled ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.medium,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: _buildButtonContent(),
              )
              : ElevatedButton(
                onPressed: isEnabled ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor ?? AppColors.primary,
                  foregroundColor: textColor ?? AppColors.surface,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppBorderRadius.medium,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: _buildButtonContent(),
              ),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: AppTextStyles.button,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: AppTextStyles.button,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }
}

// Modern Progress Indicator
class ModernProgressIndicator extends StatelessWidget {
  final double value;
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  final BorderRadius? borderRadius;

  const ModernProgressIndicator({
    super.key,
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.height = 8,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceVariant,
        borderRadius: borderRadius ?? AppBorderRadius.small,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: borderRadius ?? AppBorderRadius.small,
          ),
        ),
      ),
    );
  }
}

// --- LexiFlow Legacy/Brand Support ---

ColorScheme blendWithLexiFlowAccent(ColorScheme scheme) {
  return scheme.copyWith(
    primary: Color.lerp(scheme.primary, AppColors.primary, 0.3)!,
    primaryContainer:
        Color.lerp(scheme.primaryContainer, AppColors.primary, 0.35)!,
    secondary: Color.lerp(scheme.secondary, AppColors.secondary, 0.3)!,
    secondaryContainer:
        Color.lerp(scheme.secondaryContainer, AppColors.secondary, 0.35)!,
    tertiary: Color.lerp(scheme.tertiary, AppColors.accent, 0.3)!,
    tertiaryContainer:
        Color.lerp(scheme.tertiaryContainer, AppColors.accent, 0.35)!,
  );
}

class LexiFlowCardsPalette {
  const LexiFlowCardsPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.shadowColor,
    required this.gradient,
  });

  factory LexiFlowCardsPalette.fromScheme(
    ColorScheme scheme, {
    required Brightness brightness,
  }) {
    final tintedScheme = blendWithLexiFlowAccent(scheme);
    final isDark = brightness == Brightness.dark;

    return LexiFlowCardsPalette(
      primary: tintedScheme.primary,
      secondary: tintedScheme.secondary,
      accent: tintedScheme.tertiary,
      background: scheme.surface,
      surface: scheme.surface,
      card: isDark ? scheme.surfaceContainerHighest : scheme.surface,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      shadowColor:
          isDark
              ? Colors.black.withOpacity(0.35)
              : Colors.black.withOpacity(0.08),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tintedScheme.primaryContainer.withOpacity(0.9),
          tintedScheme.secondaryContainer.withOpacity(0.9),
        ],
      ),
    );
  }

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color shadowColor;
  final Gradient gradient;
}

class LexiFlowCardsTheme {
  const LexiFlowCardsTheme._();

  static LexiFlowCardsPalette palette(BuildContext context) {
    final theme = Theme.of(context);
    return LexiFlowCardsPalette.fromScheme(
      theme.colorScheme,
      brightness: theme.brightness,
    );
  }

  static LexiFlowCardsTypography typography(BuildContext context) {
    final currentPalette = palette(context);
    return LexiFlowCardsTypography(currentPalette);
  }
}

class LexiFlowCardsTypography {
  LexiFlowCardsTypography(this.palette);

  final LexiFlowCardsPalette palette;

  TextStyle get headline => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: palette.textPrimary,
    height: 1.3,
  );

  TextStyle get title => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: palette.textPrimary,
    height: 1.35,
  );

  TextStyle get body => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: palette.textSecondary,
    height: 1.5,
  );

  TextStyle get label => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: palette.textPrimary,
    letterSpacing: 0.2,
  );

  TextStyle get button => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: palette.surface,
    letterSpacing: 0.2,
  );
}

extension LexiFlowTypographyExtension on BuildContext {
  LexiFlowCardsTypography get cardsTypography =>
      LexiFlowCardsTheme.typography(this);

  LexiFlowCardsPalette get cardsPalette => LexiFlowCardsTheme.palette(this);
}

extension ColorOpacityExt on Color {
  Color withOpacityFraction(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

const ColorScheme lexiflowFallbackLightScheme = ColorScheme.light(
  primary: AppColors.primary,
  onPrimary: Colors.white,
  primaryContainer: AppColors.primaryLight,
  onPrimaryContainer: AppColors.textPrimary,
  secondary: AppColors.secondary,
  onSecondary: Colors.white,
  secondaryContainer: AppColors.secondaryLight,
  onSecondaryContainer: AppColors.textPrimary,
  tertiary: AppColors.accent,
  onTertiary: Colors.white,
  tertiaryContainer: AppColors.accent,
  onTertiaryContainer: AppColors.textPrimary,
  surface: AppColors.surface,
  surfaceContainerHighest: AppColors.surfaceVariant,
  onSurface: AppColors.textPrimary,
  onSurfaceVariant: AppColors.textSecondary,
  outline: AppColors.border,
  outlineVariant: AppColors.borderLight,
);

const ColorScheme lexiflowFallbackDarkScheme = ColorScheme.dark(
  primary: AppDarkColors.primary,
  onPrimary: Colors.black,
  primaryContainer: AppDarkColors.primaryDark,
  onPrimaryContainer: Colors.white,
  secondary: AppDarkColors.secondary,
  onSecondary: Colors.black,
  secondaryContainer: AppDarkColors.secondaryLight,
  onSecondaryContainer: Colors.white,
  tertiary: AppColors.accent,
  onTertiary: Colors.black,
  tertiaryContainer: AppColors.accent,
  onTertiaryContainer: Colors.white,
  surface: AppDarkColors.surface,
  surfaceContainerHighest: AppDarkColors.surfaceVariant,
  onSurface: AppDarkColors.textPrimary,
  onSurfaceVariant: AppDarkColors.textSecondary,
  outline: AppDarkColors.border,
  outlineVariant: AppDarkColors.borderLight,
);
