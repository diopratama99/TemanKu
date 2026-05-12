import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';
import 'editorial.dart';

/// Editorial empty state — eyebrow + display title + body, with hairline rule
/// and outlined CTA. No giant gradient circle icons.
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final String eyebrow;

  const EmptyStateWidget({
    required this.title,
    required this.description,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.eyebrow = 'KOSONG',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Semantics(
      label: '$title. $description',
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
              vertical: AppTheme.space48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AccentBar(width: 24, height: 2),
                    const SizedBox(width: AppTheme.space8),
                    Eyebrow(eyebrow, color: secondary),
                  ],
                ),
                const SizedBox(height: AppTheme.space20),
                Icon(
                  icon,
                  size: 32,
                  color: iconColor ?? ink,
                ),
                const SizedBox(height: AppTheme.space20),
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: -0.6,
                    color: ink,
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: secondary,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppTheme.space32),
                  const Hairline(),
                  const SizedBox(height: AppTheme.space24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!.toUpperCase()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Editorial loading state — eyebrow + slim linear progress, ink only.
class LoadingStateWidget extends StatelessWidget {
  final String? message;

  const LoadingStateWidget({this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);

    return Semantics(
      label: message ?? 'Memuat data',
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pageGutter,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Eyebrow('SEDANG MENULIS'),
              const SizedBox(height: AppTheme.space12),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: ThemeUtils.isDarkMode(context)
                      ? AppTheme.darkHairlineColor
                      : AppTheme.hairlineColor,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppTheme.space16),
                Text(
                  message!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Editorial error state.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final expense = ThemeUtils.getExpenseColor(context);
    final ink = ThemeUtils.getTextPrimary(context);

    return Semantics(
      label: '$title. $message',
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
              vertical: AppTheme.space48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 24, height: 2, color: expense),
                    const SizedBox(width: AppTheme.space8),
                    Eyebrow('GALAT', color: expense),
                  ],
                ),
                const SizedBox(height: AppTheme.space20),
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: -0.5,
                    color: ink,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: secondary,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AppTheme.space32),
                  const Hairline(),
                  const SizedBox(height: AppTheme.space24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('COBA LAGI'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Success snackbar — flat ink slab with indigo accent rule.
void showSuccessSnackbar(BuildContext context, String message) {
  final isDark = ThemeUtils.isDarkMode(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            width: 3,
            height: 24,
            color: isDark ? AppTheme.darkPrimaryColor : AppTheme.primaryColor,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      margin: const EdgeInsets.all(AppTheme.space16),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Error snackbar — flat ink slab with crimson accent rule.
void showErrorSnackbar(BuildContext context, String message) {
  final isDark = ThemeUtils.isDarkMode(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            width: 3,
            height: 24,
            color: isDark ? AppTheme.darkExpenseColor : AppTheme.expenseColor,
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      margin: const EdgeInsets.all(AppTheme.space16),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'TUTUP',
        textColor: isDark ? AppTheme.darkPrimaryColor : AppTheme.darkPrimaryColor,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}
