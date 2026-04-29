import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Utility functions for theme-aware colors
class ThemeUtils {
  /// Get primary color based on theme mode
  static Color getPrimaryColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkPrimaryColor : AppTheme.primaryColor;
  }

  /// Get brand green accent based on theme mode — for thin
  /// masthead rules and selective financial section accents.
  static Color getAccentGreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkAccentGreen : AppTheme.accentGreen;
  }

  /// Get income color based on theme mode
  static Color getIncomeColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkIncomeColor : AppTheme.incomeColor;
  }

  /// Get expense color based on theme mode
  static Color getExpenseColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor;
  }

  /// Get background color based on theme mode
  static Color getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
  }

  /// Get surface color based on theme mode
  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor;
  }

  /// Get card color based on theme mode
  static Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkCardColor : AppTheme.cardColor;
  }

  /// Get text primary color based on theme mode
  static Color getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  }

  /// Get text secondary color based on theme mode
  static Color getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  }

  /// Get text disabled color based on theme mode
  static Color getTextDisabled(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTheme.darkTextDisabled : AppTheme.textDisabled;
  }

  /// Check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
