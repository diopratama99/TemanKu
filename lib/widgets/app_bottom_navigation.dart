import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../utils/theme_utils.dart';

/// Editorial bottom navigation — flat hairline-topped bar.
///
/// 5 items, each rendered as small icon + uppercase tracked label.
/// Selected items get an indigo accent underline above the label.
/// The middle "TULIS" item is rendered with the indigo accent
/// to stand out as a primary action (replaces the floating FAB).
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeUtils.isDarkMode(context);
    final paper = ThemeUtils.getBackgroundColor(context);
    final hairline = isDark ? AppTheme.darkHairlineColor : AppTheme.hairlineColor;

    return Semantics(
      label: 'Navigasi utama aplikasi',
      child: Container(
        color: paper,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thin green brand rule, then standard hairline.
            Container(
              height: 1,
              color: ThemeUtils.getAccentGreen(context),
            ),
            Container(height: AppTheme.hairlineWidth, color: hairline),
            SafeArea(
              top: false,
              child: SizedBox(
                height: 70,
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
                _NavItem(
                  icon: Icons.add_circle_outline,
                  iconActive: Icons.add_circle,
                  label: 'TULIS',
                  isSelected: currentIndex == 2,
                  onTap: () => onDestinationSelected(2),
                  isAccent: true,
                ),
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
    );
  }
}

/// Single nav item — icon over uppercase tracked label,
/// 2px green top rule when selected.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool isSelected;
  final bool isAccent;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ThemeUtils.getPrimaryColor(context);
    final green = ThemeUtils.getAccentGreen(context);
    final ink = ThemeUtils.getTextPrimary(context);
    final secondary = ThemeUtils.getTextSecondary(context);

    final baseColor = isAccent ? accent : (isSelected ? ink : secondary);

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Stack(
            children: [
              // Top green rule for selected item — brand mark.
              if (isSelected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: green),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? iconActive : icon,
                      size: 22,
                      color: baseColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: baseColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        color: ThemeUtils.getTextPrimary(context),
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
        color: ThemeUtils.getTextPrimary(context),
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
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: Text('TULIS'),
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
