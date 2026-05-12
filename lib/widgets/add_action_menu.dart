import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';

/// Editorial **radial add-action menu**.
///
/// Three icon-only chips fan out in an arc above the lifted TAMBAH button:
///
/// ```
///        ✏  📷  🎙
///         \  |  /
///          \ | /
///          [ + ]   ← anchor (TAMBAH button)
/// ```
///
/// - **TULIS**  (pencil)  — straight up. Rendered as a green primary chip
///   so the most-used action is obvious without needing a label.
/// - **KAMERA** (camera)  — up-left at 135°.
/// - **SUARA**  (mic)     — up-right at 45°.
///
/// Chips are deliberately **icon-only** (no labels) per the simplified nav
/// language; tooltips and Semantics labels are still attached so screen
/// readers and long-press hints work.
///
/// API note: keeps the same signature as the previous bottom-sheet
/// implementation so existing call sites do not change.
Future<void> showAddActionMenu(
  BuildContext context, {
  GlobalKey? anchorKey,
  required VoidCallback onTulis,
  required VoidCallback onKamera,
  required VoidCallback onSuara,
}) async {
  // Resolve anchor centre from the supplied key (the lifted TAMBAH button)
  // so the chips fan out from exactly that point. Falls back to bottom-
  // centre when no key is supplied (e.g. NavigationRail layout on tablet).
  Offset anchorCenter;
  final renderObject = anchorKey?.currentContext?.findRenderObject();
  if (renderObject is RenderBox && renderObject.attached) {
    final topLeft = renderObject.localToGlobal(Offset.zero);
    anchorCenter = Offset(
      topLeft.dx + renderObject.size.width / 2,
      topLeft.dy + renderObject.size.height / 2,
    );
  } else {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    anchorCenter = Offset(
      size.width / 2,
      size.height - padding.bottom - 56,
    );
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup menu tambah transaksi',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _RadialMenu(
        animation: animation,
        anchorCenter: anchorCenter,
        onTulis: onTulis,
        onKamera: onKamera,
        onSuara: onSuara,
      );
    },
  );
}

class _RadialMenu extends StatelessWidget {
  final Animation<double> animation;
  final Offset anchorCenter;
  final VoidCallback onTulis;
  final VoidCallback onKamera;
  final VoidCallback onSuara;

  const _RadialMenu({
    required this.animation,
    required this.anchorCenter,
    required this.onTulis,
    required this.onKamera,
    required this.onSuara,
  });

  /// Distance (in logical pixels) from the anchor centre to each chip
  /// centre. Tuned so chips don't overlap each other or the bar above
  /// safe-area on small phones (~28px gap between adjacent chips).
  static const double _radius = 110;

  /// Chip diameter.
  static const double _chipSize = 56;

  /// Chip target offsets relative to anchor centre. Y axis is screen-down
  /// so we negate the sin component to push chips upwards.
  ({Offset tulis, Offset kamera, Offset suara}) _targets(
    Size screen,
    EdgeInsets safe,
  ) {
    Offset polar(double degrees) {
      final rad = degrees * math.pi / 180;
      return Offset(math.cos(rad) * _radius, -math.sin(rad) * _radius);
    }

    final raw = (
      tulis: polar(90),
      kamera: polar(135),
      suara: polar(45),
    );

    // Clamp each chip's eventual top-left to the screen so we never draw
    // outside the visible area on tiny phones.
    Offset clamp(Offset relative) {
      final cx = anchorCenter.dx + relative.dx;
      final cy = anchorCenter.dy + relative.dy;
      final maxX = screen.width - _chipSize / 2 - 12;
      final minX = _chipSize / 2 + 12;
      final maxY = screen.height - _chipSize / 2 - 12;
      final minY = safe.top + _chipSize / 2 + 12;
      return Offset(
        cx.clamp(minX, maxX) - anchorCenter.dx,
        cy.clamp(minY, maxY) - anchorCenter.dy,
      );
    }

    return (
      tulis: clamp(raw.tulis),
      kamera: clamp(raw.kamera),
      suara: clamp(raw.suara),
    );
  }

  Future<void> _close(BuildContext context, {VoidCallback? then}) async {
    Navigator.of(context).pop();
    if (then != null) {
      // Tiny breathing gap so the dialog has time to fade before the
      // next route's transition starts; keeps animations from fighting.
      await Future.delayed(const Duration(milliseconds: 60));
      then();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final t = _targets(mq.size, mq.padding);
    final ink = ThemeUtils.getTextPrimary(context);
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);
    final green = ThemeUtils.getAccentGreen(context);
    final hairline = ThemeUtils.isDarkMode(context)
        ? AppTheme.darkHairlineColor
        : AppTheme.hairlineColor;

    final scrim = Tween<double>(begin: 0, end: 0.50).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOut),
    );

    return Stack(
      children: [
        // Animated scrim — full-screen, also dismisses the menu on tap.
        AnimatedBuilder(
          animation: scrim,
          builder: (_, __) => Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(context),
              child: Container(
                color: Colors.black.withValues(alpha: scrim.value),
              ),
            ),
          ),
        ),

        // Three fan-out chips. Index controls stagger order so the
        // primary (TULIS) lands a hair before the side chips.
        _RadialChip(
          animation: animation,
          staggerStart: 0.05,
          anchor: anchorCenter,
          target: t.tulis,
          size: _chipSize,
          icon: Icons.edit_outlined,
          tooltip: 'Tulis manual',
          isPrimary: true,
          ink: ink,
          paper: paper,
          green: green,
          hairline: hairline,
          secondary: secondary,
          onTap: () => _close(context, then: onTulis),
        ),
        _RadialChip(
          animation: animation,
          staggerStart: 0.12,
          anchor: anchorCenter,
          target: t.kamera,
          size: _chipSize,
          icon: Icons.photo_camera_outlined,
          tooltip: 'Foto struk',
          isPrimary: false,
          ink: ink,
          paper: paper,
          green: green,
          hairline: hairline,
          secondary: secondary,
          onTap: () => _close(context, then: onKamera),
        ),
        _RadialChip(
          animation: animation,
          staggerStart: 0.12,
          anchor: anchorCenter,
          target: t.suara,
          size: _chipSize,
          icon: Icons.mic_none_rounded,
          tooltip: 'Rekam suara',
          isPrimary: false,
          ink: ink,
          paper: paper,
          green: green,
          hairline: hairline,
          secondary: secondary,
          onTap: () => _close(context, then: onSuara),
        ),
      ],
    );
  }
}

/// Single fan-out icon chip. Animates from anchor centre to its [target]
/// offset (relative to anchor) with scale + fade. The primary chip uses a
/// green fill so the default action stays obvious without text labels.
class _RadialChip extends StatelessWidget {
  final Animation<double> animation;
  final double staggerStart;
  final Offset anchor;
  final Offset target;
  final double size;
  final IconData icon;
  final String tooltip;
  final bool isPrimary;
  final Color ink;
  final Color paper;
  final Color green;
  final Color hairline;
  final Color secondary;
  final VoidCallback onTap;

  const _RadialChip({
    required this.animation,
    required this.staggerStart,
    required this.anchor,
    required this.target,
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.isPrimary,
    required this.ink,
    required this.paper,
    required this.green,
    required this.hairline,
    required this.secondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(
        staggerStart,
        (staggerStart + 0.70).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        final t = curve.value.clamp(0.0, 1.0);
        // Translate from anchor centre (t=0) to anchor + target (t=1).
        final cx = anchor.dx + target.dx * t;
        final cy = anchor.dy + target.dy * t;
        final scale = 0.4 + 0.6 * t;
        final opacity = t.clamp(0.0, 1.0);

        return Positioned(
          left: cx - size / 2,
          top: cy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            ignoring: t < 0.5,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: _Chip(
                  icon: icon,
                  tooltip: tooltip,
                  isPrimary: isPrimary,
                  ink: ink,
                  paper: paper,
                  green: green,
                  hairline: hairline,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Static visual for one fan-out chip. Pulled out of the animated build
/// so the [Material] / [InkWell] are not rebuilt every animation frame.
class _Chip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isPrimary;
  final Color ink;
  final Color paper;
  final Color green;
  final Color hairline;
  final VoidCallback onTap;

  const _Chip({
    required this.icon,
    required this.tooltip,
    required this.isPrimary,
    required this.ink,
    required this.paper,
    required this.green,
    required this.hairline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isPrimary ? green : paper;
    final iconColor = isPrimary ? paper : ink;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: fillColor,
              shape: BoxShape.circle,
              border: isPrimary
                  ? null
                  : Border.all(
                      color: hairline,
                      width: AppTheme.hairlineWidth,
                    ),
              boxShadow: [
                BoxShadow(
                  color: (isPrimary ? green : Colors.black).withValues(
                    alpha: isPrimary ? 0.30 : 0.10,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: green.withValues(alpha: 0.12),
              highlightColor: green.withValues(alpha: 0.05),
              child: Center(
                child: Icon(icon, size: 24, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
