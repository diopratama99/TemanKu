import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';

/// Editorial bottom navigation — **lifted FAB** layout.
///
/// Layout:
///
/// ```
///                       ╭───╮
///                       │ + │   ← lifted TAMBAH (green, sits above bar)
///                       ╰───╯
///   ─────────────────────────────────────  ← green brand rule + hairline
///    🏠     📊            🥧     👤
///   slot1  slot2  (gap)  slot4  slot5
/// ```
///
/// - Four destination items (BERANDA / ANALISA / BUDGET / PROFIL) sit flat
///   inside the bar. The middle slot is a gap reserved for the lifted
///   TAMBAH button.
/// - The TAMBAH button is the primary CTA; it always renders as a green
///   filled circle with a soft shadow that **straddles the top of the bar**
///   (half above, half inside) so it visually pops out — matching the
///   "lifted pill" pattern in the reference.
/// - Active destination items show a green filled circle behind the icon
///   (no labels). Inactive items are bare outline icons.
/// - Labels are dropped from the visual layout but retained for [Tooltip]
///   and [Semantics] so accessibility / long-press hints still work.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// When provided, tapping the centre TAMBAH button invokes this callback
  /// instead of `onDestinationSelected(2)` so the host can present the
  /// radial add-action menu (TULIS / KAMERA / REKAM SUARA).
  final VoidCallback? onAddPressed;

  /// Optional GlobalKey attached to the lifted TAMBAH button. The radial
  /// menu reads its global position from this key to anchor the fan-out
  /// of the three icon chips.
  final GlobalKey? addAnchorKey;

  const AppBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    this.onAddPressed,
    this.addAnchorKey,
    super.key,
  });

  /// Visible bar height (excluding lift overhang and bottom safe area).
  /// 72px gives icon+label items comfortable breathing room above any
  /// gesture-nav indicator on Android while keeping the bar compact.
  static const double barHeight = 72;

  /// How far above the bar's top edge the TAMBAH button is lifted. The
  /// button sits mostly inside the bar (~70%) with a small overhang on
  /// top so it still reads as a lifted FAB without floating away from
  /// the bar.
  static const double _liftOverhang = 16;

  static const double _addButtonSize = 64;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeUtils.isDarkMode(context);
    final paper = ThemeUtils.getBackgroundColor(context);
    final hairline =
        isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;
    final green = ThemeUtils.getAccentGreen(context);

    return Semantics(
      label: 'Navigasi utama aplikasi',
      child: Container(
        // Paint the bottom safe-area in paper colour too so the gesture
        // strip on Android gestures matches the bar.
        color: paper,
        child: SafeArea(
          top: false,
          child: SizedBox(
            // Total widget height = bar + lift overhang. Children with
            // `Stack(clipBehavior: Clip.none)` can render outside this
            // box, so we add a tiny breathing pad above for the shadow.
            height: barHeight + _liftOverhang + 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ─── Background bar (4 items + middle gap) ─────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: barHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: paper,
                      border: Border(
                        top: BorderSide(
                          color: hairline,
                          width: AppTheme.hairlineWidth,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Editorial brand rule — kept as masthead so the
                        // bar still belongs to the editorial page family.
                        Container(height: 1, color: green),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space8,
                            ),
                            child: Row(
                              children: [
                                _NavItem(
                                  icon: Icons.home_outlined,
                                  iconActive: Icons.home,
                                  label: 'BERANDA',
                                  isSelected: currentIndex == 0,
                                  onTap: () => onDestinationSelected(0),
                                ),
                                _NavItem(
                                  icon: Icons.show_chart,
                                  iconActive: Icons.bar_chart_rounded,
                                  label: 'ANALISA',
                                  isSelected: currentIndex == 1,
                                  onTap: () => onDestinationSelected(1),
                                ),
                                // Gap reserved for the lifted TAMBAH button.
                                const Expanded(child: SizedBox()),
                                _NavItem(
                                  icon: Icons.pie_chart_outline,
                                  iconActive: Icons.pie_chart,
                                  label: 'BUDGET',
                                  isSelected: currentIndex == 3,
                                  onTap: () => onDestinationSelected(3),
                                ),
                                _NavItem(
                                  icon: Icons.person_outline,
                                  iconActive: Icons.person,
                                  label: 'PROFIL',
                                  isSelected: currentIndex == 4,
                                  onTap: () => onDestinationSelected(4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Lifted TAMBAH button ──────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _addButtonSize,
                  child: Center(
                    child: _AddButton(
                      key: addAnchorKey,
                      size: _addButtonSize,
                      isSelected: currentIndex == 2,
                      onTap:
                          onAddPressed ?? () => onDestinationSelected(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single nav item — green pill behind the icon when selected, with a
/// small uppercase tracked label below. The label colour mirrors the
/// active state (green when selected, secondary otherwise).
///
/// Layout uses a fixed-size icon slot so the label stays anchored on the
/// same baseline regardless of selection state — otherwise the slight
/// pill size animation would jitter the label up/down.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final green = ThemeUtils.getAccentGreen(context);
    final paper = ThemeUtils.getBackgroundColor(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    final iconColor = isSelected ? paper : secondary;
    final labelColor = isSelected ? green : secondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkResponse(
            onTap: onTap,
            radius: 32,
            highlightColor: Colors.transparent,
            splashColor: green.withValues(alpha: 0.10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fixed-size icon slot keeps the label baseline stable.
                SizedBox(
                  width: 40,
                  height: 38,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 36 : 32,
                      height: isSelected ? 36 : 32,
                      decoration: BoxDecoration(
                        color: isSelected ? green : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Icon(
                          isSelected ? iconActive : icon,
                          key: ValueKey(
                            '${isSelected ? 'on' : 'off'}-${icon.codePoint}',
                          ),
                          size: 20,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    height: 1.0,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lifted FAB-style "TAMBAH" button. Always green-filled, with a soft
/// shadow so it visibly pops above the bar. The widget [key] is forwarded
/// so the radial menu can locate the global anchor position.
class _AddButton extends StatelessWidget {
  final double size;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddButton({
    required this.size,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final green = ThemeUtils.getAccentGreen(context);
    final paper = ThemeUtils.getBackgroundColor(context);
    final isDark = ThemeUtils.isDarkMode(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Tambah transaksi',
      child: Tooltip(
        message: 'Tambah transaksi',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: paper.withValues(alpha: 0.18),
            highlightColor: paper.withValues(alpha: 0.06),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: green,
                shape: BoxShape.circle,
                // White paper "halo" ring around the button. This is the
                // trick that makes the button look like it punches through
                // the bar in the reference design — the ring blends into
                // the bar so the FAB reads as floating.
                border: Border.all(
                  color: paper,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: green.withValues(
                      alpha: isDark ? 0.45 : 0.30,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.add_rounded,
                color: paper,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation rail for tablet/desktop layouts — editorial style
/// with hairline divider and tracked labels.
class AppNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      backgroundColor: ThemeUtils.getBackgroundColor(context),
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(
        color: ThemeUtils.getAccentGreen(context),
        size: 22,
      ),
      unselectedIconTheme: IconThemeData(
        color: ThemeUtils.getTextSecondary(context),
        size: 22,
      ),
      selectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: ThemeUtils.getAccentGreen(context),
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: ThemeUtils.getTextSecondary(context),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('BERANDA'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.show_chart),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: Text('ANALISA'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.add),
          selectedIcon: Icon(Icons.add),
          label: Text('TAMBAH'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.pie_chart_outline),
          selectedIcon: Icon(Icons.pie_chart),
          label: Text('BUDGET'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('PROFIL'),
        ),
      ],
    );
  }
}
