import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Editorial / Magazine-style design system.
///
/// Principles:
/// - Typography-first hierarchy (Space Grotesk display + Inter body).
/// - Single indigo accent (used sparingly — like a print highlight).
/// - Hairline 1px dividers, no shadows, no gradients, no glass.
/// - Flat paper-neutral surfaces.
/// - Generous whitespace and asymmetric, baseline-aligned layouts.
class AppTheme {
  // ============================================================
  // DESIGN TOKENS - Editorial Color System (Light / Paper)
  // ============================================================

  /// Single accent — indigo, used like a print highlight.
  static const Color primaryColor = Color(0xFF3730A3); // Indigo 800
  static const Color accentColor = primaryColor;
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Brand accent — forest green, used as a thin masthead rule
  /// and selectively for financial sections (BRANKAS, TABUNGAN).
  /// Kept restrained: only as 1–2px lines, never as fills.
  static const Color accentGreen = Color(0xFF166534); // Forest green 800

  /// Semantic financial colors — restrained, secondary to typography.
  static const Color incomeColor = Color(0xFF15803D); // Forest green 700
  static const Color expenseColor = Color(0xFFB91C1C); // Crimson 700
  static const Color neutralColor = Color(0xFF44403C); // Stone 700

  /// Paper surfaces — flat, warm off-white.
  static const Color backgroundColor = Color(0xFFF7F4EE); // Warm paper
  static const Color surfaceColor = Color(0xFFFBF8F2); // Lighter paper
  static const Color cardColor = Color(0xFFFFFFFF); // White (with hairline)

  /// Ink hierarchy — typography carries the emphasis.
  static const Color textPrimary = Color(0xFF111111); // Ink black
  static const Color textSecondary = Color(0xFF6B6B6B); // Mid grey
  static const Color textDisabled = Color(0xFFB8B5AE); // Soft grey

  /// Hairline — 1px column separator, like newspaper rules.
  static const Color hairlineColor = Color(0xFFE3DED2);

  // ============================================================
  // DARK MODE — Night edition (paper-on-night)
  // ============================================================

  static const Color darkPrimaryColor = Color(0xFFA5B4FC); // Indigo 300 (legible on dark)
  static const Color darkOnPrimary = Color(0xFF1E1B4B);

  /// Dark-mode brand green — soft mint, paired with darkPrimaryColor.
  static const Color darkAccentGreen = Color(0xFF86EFAC); // Green 300

  static const Color darkIncomeColor = Color(0xFF4ADE80); // Green 400
  static const Color darkExpenseColor = Color(0xFFF87171); // Red 400

  static const Color darkBackgroundColor = Color(0xFF111111); // Deep ink
  static const Color darkSurfaceColor = Color(0xFF161616);
  static const Color darkCardColor = Color(0xFF1C1C1C);

  static const Color darkTextPrimary = Color(0xFFF5F1EA); // Paper on dark
  static const Color darkTextSecondary = Color(0xFFA8A29E);
  static const Color darkTextDisabled = Color(0xFF57534E);

  static const Color darkHairlineColor = Color(0xFF2A2A2A);

  // ============================================================
  // DESIGN TOKENS - Spacing (generous editorial scale)
  // ============================================================
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;

  /// Standard editorial gutter — used as horizontal page padding.
  static const double pageGutter = 24.0;

  // ============================================================
  // DESIGN TOKENS - Radius (minimal, almost square)
  // ============================================================
  static const double elevation1 = 0.0;
  static const double elevation2 = 0.0;
  static const double elevation3 = 0.0;

  static const double radiusSmall = 2.0;
  static const double radiusMedium = 4.0;
  static const double radiusLarge = 6.0;
  static const double radiusXLarge = 8.0;

  static const double hairlineWidth = 1.0;

  // ============================================================
  // DESIGN TOKENS - Touch Targets (Accessibility)
  // ============================================================
  static const double minTouchTarget = 48.0;

  // ============================================================
  // Editorial Typography helpers
  // ============================================================

  /// Display style — Space Grotesk, used for hero titles & numbers (32–44px).
  static TextStyle display({
    double size = 40,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w600,
    double height = 1.05,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: -0.8,
    );
  }

  /// Eyebrow style — small uppercase tracked label (article category).
  static TextStyle eyebrow({
    Color color = textSecondary,
    double size = 11,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      height: 1.2,
      color: color,
    );
  }

  /// Body serif — optional pull-quote / italic accents.
  static TextStyle pullQuote({Color color = textPrimary}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 18,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      height: 1.5,
      color: color,
    );
  }

  // ============================================================
  // Theme Builder — Light (Paper)
  // ============================================================
  static ThemeData theme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
    );

    // Typography: Inter for body/label, Space Grotesk for display.
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      // Display — Space Grotesk hero hierarchy.
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: textPrimary,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: textPrimary,
        letterSpacing: -0.8,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: textPrimary,
        letterSpacing: -0.6,
      ),

      // Headline — Space Grotesk for section titles.
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: textPrimary,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: textPrimary,
        letterSpacing: -0.4,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: textPrimary,
        letterSpacing: -0.2,
      ),

      // Title — Space Grotesk for sub-titles.
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: textPrimary,
        letterSpacing: -0.1,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textPrimary,
        letterSpacing: 0,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: textPrimary,
        letterSpacing: 0,
      ),

      // Body — Inter for content.
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: textPrimary,
        letterSpacing: 0,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: textPrimary,
        letterSpacing: 0,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: textSecondary,
        letterSpacing: 0,
      ),

      // Label — Inter, used for buttons & nav.
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.4,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 1.4,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 1.6,
      ),
    );

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        onPrimary: onPrimary,
        secondary: primaryColor,
        error: expenseColor,
        surface: surfaceColor,
        onSurface: textPrimary,
        outline: hairlineColor,
        outlineVariant: hairlineColor,
      ),

      // AppBar — flat, paper bg, ink title (no green bar).
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
        actionsIconTheme: const IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        toolbarHeight: 64,
      ),

      textTheme: textTheme,

      // SnackBar — flat ink slab.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: backgroundColor,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      // Chip — square-ish hairline outline.
      chipTheme: ChipThemeData(
        backgroundColor: backgroundColor,
        selectedColor: textPrimary,
        labelStyle: textTheme.labelLarge?.copyWith(color: textPrimary),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: backgroundColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: hairlineColor, width: hairlineWidth),
        ),
        padding: const EdgeInsets.symmetric(horizontal: space12, vertical: space8),
        side: const BorderSide(color: hairlineColor, width: hairlineWidth),
        showCheckmark: false,
      ),

      // Card — flat white slab with hairline border.
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: hairlineColor, width: hairlineWidth),
        ),
        margin: EdgeInsets.zero,
      ),

      // Inputs — underline-only (newspaper field), no fill.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: space12,
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: hairlineColor, width: hairlineWidth),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: hairlineColor, width: hairlineWidth),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: expenseColor, width: hairlineWidth),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: expenseColor, width: 1.5),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: textSecondary,
          letterSpacing: 1.4,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: primaryColor,
          letterSpacing: 1.4,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: expenseColor),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        prefixStyle: textTheme.bodyMedium,
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      // Filled button — square ink slab (or indigo accent).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: backgroundColor,
          disabledBackgroundColor: textDisabled,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: space24,
            vertical: space16,
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
          elevation: 0,
        ),
      ),

      // Outlined button — hairline border.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          side: const BorderSide(color: textPrimary, width: hairlineWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: space24,
            vertical: space16,
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        ),
      ),

      // Text button — indigo accent only.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(0, minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: space12,
            vertical: space8,
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.4),
        ),
      ),

      // List tile.
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        iconColor: textPrimary,
        minVerticalPadding: space12,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: space8,
        ),
      ),

      // Divider — hairline.
      dividerTheme: const DividerThemeData(
        color: hairlineColor,
        thickness: hairlineWidth,
        space: space24,
      ),
      dividerColor: hairlineColor,

      // Tab bar — flat with green underline (brand mark).
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        labelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: accentGreen, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: hairlineColor,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Bottom nav — flat hairline-topped bar.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundColor,
        elevation: 0,
        height: 64,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: textPrimary,
              letterSpacing: 1.4,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: textSecondary,
            letterSpacing: 1.4,
          );
        }),
      ),

      // FAB.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: textPrimary,
        foregroundColor: backgroundColor,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
        ),
      ),

      // Dialog.
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: hairlineColor, width: hairlineWidth),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      // Bottom sheet.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSmall)),
          side: BorderSide(color: hairlineColor, width: hairlineWidth),
        ),
      ),

      // Progress.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: hairlineColor,
        circularTrackColor: hairlineColor,
      ),

      iconTheme: const IconThemeData(color: textPrimary, size: 22),
      splashFactory: InkRipple.splashFactory,
      splashColor: hairlineColor,
      highlightColor: Colors.transparent,
    );
  }

  // ============================================================
  // Theme Builder — Dark (Night Edition)
  // ============================================================
  static ThemeData darkTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimaryColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: darkBackgroundColor,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: darkTextPrimary,
        letterSpacing: -1.0,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: darkTextPrimary,
        letterSpacing: -0.8,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: darkTextPrimary,
        letterSpacing: -0.6,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: darkTextPrimary,
        letterSpacing: -0.6,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: darkTextPrimary,
        letterSpacing: -0.4,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: darkTextPrimary,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: darkTextPrimary,
        letterSpacing: -0.1,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: darkTextPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: darkTextPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: darkTextPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: darkTextPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: darkTextSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.4,
        color: darkTextPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 1.4,
        color: darkTextSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 1.6,
        color: darkTextSecondary,
      ),
    );

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: darkPrimaryColor,
        onPrimary: darkOnPrimary,
        secondary: darkPrimaryColor,
        error: darkExpenseColor,
        surface: darkSurfaceColor,
        onSurface: darkTextPrimary,
        outline: darkHairlineColor,
        outlineVariant: darkHairlineColor,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: darkBackgroundColor,
        foregroundColor: darkTextPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
        actionsIconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: -0.2,
        ),
        toolbarHeight: 64,
      ),

      textTheme: textTheme,

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: darkBackgroundColor,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: darkBackgroundColor,
        selectedColor: darkTextPrimary,
        labelStyle: textTheme.labelLarge?.copyWith(color: darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: darkHairlineColor, width: hairlineWidth),
        ),
        padding: const EdgeInsets.symmetric(horizontal: space12, vertical: space8),
        side: const BorderSide(color: darkHairlineColor, width: hairlineWidth),
        showCheckmark: false,
      ),

      cardTheme: CardThemeData(
        color: darkCardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: darkHairlineColor, width: hairlineWidth),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: space12,
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: darkHairlineColor, width: hairlineWidth),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: darkHairlineColor, width: hairlineWidth),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: darkPrimaryColor, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: darkExpenseColor, width: hairlineWidth),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: darkExpenseColor, width: 1.5),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: darkTextSecondary,
          letterSpacing: 1.4,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: darkPrimaryColor,
          letterSpacing: 1.4,
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: darkExpenseColor),
        hintStyle: textTheme.bodyMedium?.copyWith(color: darkTextSecondary),
        prefixStyle: textTheme.bodyMedium,
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkTextPrimary,
          foregroundColor: darkBackgroundColor,
          disabledBackgroundColor: darkTextDisabled,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: space24,
            vertical: space16,
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          side: const BorderSide(color: darkTextPrimary, width: hairlineWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: space24,
            vertical: space16,
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimaryColor,
          minimumSize: const Size(0, minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: space12,
            vertical: space8,
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.4),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        iconColor: darkTextPrimary,
        minVerticalPadding: space12,
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: space8),
      ),

      dividerTheme: const DividerThemeData(
        color: darkHairlineColor,
        thickness: hairlineWidth,
        space: space24,
      ),
      dividerColor: darkHairlineColor,

      tabBarTheme: TabBarThemeData(
        labelColor: darkTextPrimary,
        unselectedLabelColor: darkTextSecondary,
        labelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: darkAccentGreen, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: darkHairlineColor,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackgroundColor,
        elevation: 0,
        height: 64,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              color: darkTextPrimary,
              letterSpacing: 1.4,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: darkTextSecondary,
            letterSpacing: 1.4,
          );
        }),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkTextPrimary,
        foregroundColor: darkBackgroundColor,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: darkCardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          side: const BorderSide(color: darkHairlineColor, width: hairlineWidth),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSmall)),
          side: BorderSide(color: darkHairlineColor, width: hairlineWidth),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkPrimaryColor,
        linearTrackColor: darkHairlineColor,
        circularTrackColor: darkHairlineColor,
      ),

      iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
      splashFactory: InkRipple.splashFactory,
      splashColor: darkHairlineColor,
      highlightColor: Colors.transparent,
    );
  }
}

