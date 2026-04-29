import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';

/// ============================================================
/// Editorial / Magazine widget kit.
///
/// Building blocks shared across the app to keep the magazine
/// language consistent: eyebrows, hairlines, display titles,
/// asymmetric headers, list rows, etc.
/// ============================================================

/// Small uppercase tracked label — borrowed from magazine
/// section labels ("BRANKAS", "COBA TANYA").
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;

  const Eyebrow(this.text, {this.color, this.size = 11, super.key});

  @override
  Widget build(BuildContext context) {
    final c = color ?? ThemeUtils.getTextSecondary(context);
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        height: 1.2,
        color: c,
      ),
    );
  }
}

/// 1px hairline divider — newspaper column rule.
class Hairline extends StatelessWidget {
  final double thickness;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const Hairline({this.thickness = 1.0, this.color, this.margin, super.key});

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        (ThemeUtils.isDarkMode(context)
            ? AppTheme.darkHairlineColor
            : AppTheme.hairlineColor);
    return Container(
      margin: margin,
      height: thickness,
      width: double.infinity,
      color: c,
    );
  }
}

/// Vertical hairline — used between asymmetric columns.
class VerticalHairline extends StatelessWidget {
  final double thickness;
  final double? height;
  final Color? color;

  const VerticalHairline({
    this.thickness = 1.0,
    this.height,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        (ThemeUtils.isDarkMode(context)
            ? AppTheme.darkHairlineColor
            : AppTheme.hairlineColor);
    return Container(width: thickness, height: height, color: c);
  }
}

/// Indigo accent bar — used like a print highlight strip.
class AccentBar extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const AccentBar({this.width = 32, this.height = 2, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color ?? ThemeUtils.getPrimaryColor(context),
    );
  }
}

/// Editorial display title — Space Grotesk hero typography.
class DisplayTitle extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? align;
  final int? maxLines;

  const DisplayTitle(
    this.text, {
    this.size = 36,
    this.weight = FontWeight.w600,
    this.color,
    this.align,
    this.maxLines,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: align,
      style: GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        height: 1.05,
        letterSpacing: -0.8,
        color: color ?? ThemeUtils.getTextPrimary(context),
      ),
    );
  }
}

/// Asymmetric editorial page header.
///
/// Renders an eyebrow + display title on the left, optional
/// meta info on the right, baseline-aligned, and a hairline
/// underneath — like a magazine section opener.
///
/// A 1px forest-green masthead rule sits at the very top as
/// a subtle brand mark, paired with the indigo accent bar.
class EditorialHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? meta;
  final String? metaEyebrow;
  final double titleSize;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  final bool showHairline;
  final bool showBackButton;
  final VoidCallback? onBack;

  /// When true, draws a thin green rule at the top of the header
  /// as the magazine "masthead". On by default.
  final bool showMasthead;

  const EditorialHeader({
    required this.eyebrow,
    required this.title,
    this.meta,
    this.metaEyebrow,
    this.titleSize = 36,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.pageGutter,
      AppTheme.space32,
      AppTheme.pageGutter,
      AppTheme.space24,
    ),
    this.trailing,
    this.showHairline = true,
    this.showMasthead = true,
    this.showBackButton = false,
    this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final canPop = Navigator.canPop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMasthead)
          Container(height: 1, color: ThemeUtils.getAccentGreen(context)),
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Eyebrow + title — left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showBackButton && canPop)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onBack ?? () => Navigator.pop(context),
                                child: SizedBox(
                                  width: 24,
                                  height: 20,
                                  child: Icon(
                                    Icons.chevron_left,
                                    size: 20,
                                    color: secondary,
                                  ),
                                ),
                              )
                            else
                              const AccentBar(width: 24, height: 2),
                            const SizedBox(width: AppTheme.space8),
                            Eyebrow(eyebrow, color: secondary),
                          ],
                        ),
                        const SizedBox(height: AppTheme.space12),
                        DisplayTitle(title, size: titleSize),
                      ],
                    ),
                  ),
                  if (meta != null || trailing != null) ...[
                    const SizedBox(width: AppTheme.space16),
                    // Meta — right column
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.space4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (metaEyebrow != null)
                            Eyebrow(metaEyebrow!, color: secondary),
                          if (metaEyebrow != null)
                            const SizedBox(height: AppTheme.space4),
                          if (meta != null)
                            Text(
                              meta!,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: ThemeUtils.getTextPrimary(context),
                              ),
                            ),
                          if (trailing != null) ...[
                            if (meta != null)
                              const SizedBox(height: AppTheme.space8),
                            trailing!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (showHairline) ...[
                const SizedBox(height: AppTheme.space24),
                const Hairline(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Section header — eyebrow + title with hairline above.
class EditorialSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool topHairline;

  const EditorialSectionHeader({
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
    this.topHairline = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topHairline) const Hairline(),
        Padding(
          padding: padding.add(
            const EdgeInsets.only(
              top: AppTheme.space24,
              bottom: AppTheme.space16,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.2,
                        color: ThemeUtils.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

/// Flat editorial card — paper slab with hairline border.
/// Use this in place of the previous gradient/shadow cards.
class EditorialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? background;

  const EditorialCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space20),
    this.margin,
    this.onTap,
    this.background,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeUtils.isDarkMode(context);
    final bg =
        background ?? (isDark ? AppTheme.darkCardColor : AppTheme.cardColor);
    final border = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;

    final container = Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: AppTheme.hairlineWidth),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return Container(margin: margin, child: container);
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: container,
        ),
      ),
    );
  }
}

/// Editorial list row — three column layout with hairline below.
/// Used for transactions, accounts, budgets, etc.
class EditorialListRow extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String value;
  final String? valueEyebrow;
  final Color? valueColor;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showHairline;
  final EdgeInsetsGeometry padding;

  const EditorialListRow({
    required this.title,
    required this.value,
    this.eyebrow,
    this.subtitle,
    this.valueEyebrow,
    this.valueColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.showHairline = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.pageGutter,
      vertical: AppTheme.space20,
    ),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppTheme.space16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Eyebrow(eyebrow!, color: secondary),
                const SizedBox(height: AppTheme.space4),
              ],
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppTheme.space4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: secondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (valueEyebrow != null) ...[
              Eyebrow(valueEyebrow!, color: secondary, size: 10),
              const SizedBox(height: AppTheme.space4),
            ],
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: valueColor ?? ink,
              ),
            ),
          ],
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.space12),
          trailing!,
        ],
      ],
    );

    final body = Padding(padding: padding, child: row);

    final tappable = onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: body),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [tappable, if (showHairline) const Hairline()],
    );
  }
}

/// Editorial number stat — eyebrow + display number, optional caption.
class EditorialStat extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final double valueSize;
  final Color? valueColor;
  final CrossAxisAlignment alignment;

  const EditorialStat({
    required this.label,
    required this.value,
    this.caption,
    this.valueSize = 26,
    this.valueColor,
    this.alignment = CrossAxisAlignment.start,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = ThemeUtils.getTextSecondary(context);
    final ink = ThemeUtils.getTextPrimary(context);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Eyebrow(label, color: secondary),
        const SizedBox(height: AppTheme.space8),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: valueSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1.1,
            color: valueColor ?? ink,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppTheme.space4),
          Text(
            caption!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: secondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Asymmetric two-column block: title left, content right.
/// Used for editorial body content.
class EditorialColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final EdgeInsetsGeometry padding;
  final double gap;

  const EditorialColumns({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
    this.gap = AppTheme.space16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          SizedBox(width: gap),
          Expanded(flex: rightFlex, child: right),
        ],
      ),
    );
  }
}

/// Page wrap — gives consistent paper background and gutter.
class EditorialPage extends StatelessWidget {
  final Widget child;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const EditorialPage({
    required this.child,
    this.physics,
    this.controller,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThemeUtils.getBackgroundColor(context),
      child: child,
    );
  }
}

/// Tag chip — square, hairline outline, optionally filled.
class EditorialTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const EditorialTag({
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeUtils.isDarkMode(context);
    final ink = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final paper = isDark
        ? AppTheme.darkBackgroundColor
        : AppTheme.backgroundColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space8,
          ),
          decoration: BoxDecoration(
            color: selected ? ink : paper,
            border: Border.all(color: ink, width: AppTheme.hairlineWidth),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: selected ? paper : ink,
            ),
          ),
        ),
      ),
    );
  }
}
