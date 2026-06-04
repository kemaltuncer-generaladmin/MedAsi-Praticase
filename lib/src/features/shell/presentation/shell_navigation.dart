import 'package:flutter/material.dart';

import '../../../app/theme/praticase_colors.dart';
import '../../../app/theme/praticase_motion.dart';
import '../../../app/theme/praticase_tokens.dart';
import '../../../shared/ui/responsive.dart';

class PratiCaseSideNavigation extends StatelessWidget {
  const PratiCaseSideNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final extended = PratiCaseResponsive.isDesktop(context);
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      minWidth: 88,
      minExtendedWidth: 224,
      groupAlignment: -0.72,
      backgroundColor: PratiCaseColors.white,
      indicatorColor: PratiCaseColors.teal.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: PratiCaseColors.teal),
      unselectedIconTheme: const IconThemeData(color: PratiCaseColors.muted),
      selectedLabelTextStyle: const TextStyle(
        color: PratiCaseColors.teal,
        fontWeight: FontWeight.w900,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: PratiCaseColors.muted,
        fontWeight: FontWeight.w700,
      ),
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
        child: _RailBrand(extended: extended),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Ana Sayfa'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: Text('Cüzdan'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: Text('Sınavlar'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.trending_up_outlined),
          selectedIcon: Icon(Icons.trending_up_rounded),
          label: Text('Gelişim'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profilim'),
        ),
      ],
    );
  }
}

class PratiCaseBottomNav extends StatelessWidget {
  const PratiCaseBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = PratiCaseResponsive.isCompactPhone(context);
    final navHeight = PratiCaseResponsive.bottomNavigationHeightForWidth(width);
    final horizontalInset = compact ? 10.0 : 16.0;
    final bottomInset =
        PratiCaseResponsive.bottomNavigationOuterPaddingForWidth(width);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          bottomInset,
        ),
        child: Container(
          height: navHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7),
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
            border: Border.all(
              color: PratiCaseColors.border.withValues(alpha: 0.60),
            ),
            boxShadow: PratiCaseShadows.floating,
          ),
          child: Row(
            children: [
              _NavItem(
                identifier: 'nav.home',
                selected: selectedIndex == 0,
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                onTap: () => onSelected(0),
              ),
              _NavItem(
                identifier: 'nav.wallet',
                selected: selectedIndex == 1,
                icon: selectedIndex == 1
                    ? Icons.account_balance_wallet_rounded
                    : Icons.account_balance_wallet_outlined,
                label: 'Cüzdan',
                onTap: () => onSelected(1),
              ),
              _NavItem(
                identifier: 'nav.exams',
                selected: selectedIndex == 2,
                icon: Icons.assignment_rounded,
                label: 'Sınavlar',
                onTap: () => onSelected(2),
              ),
              _NavItem(
                identifier: 'nav.progress',
                selected: selectedIndex == 3,
                icon: Icons.trending_up_rounded,
                label: 'Gelişim',
                onTap: () => onSelected(3),
              ),
              _NavItem(
                identifier: 'nav.profile',
                selected: selectedIndex == 4,
                icon: selectedIndex == 4
                    ? Icons.person_rounded
                    : Icons.person_outline_rounded,
                label: 'Profilim',
                onTap: () => onSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(PratiCaseRadius.md),
      child: Image.asset(
        'assets/auth/praticase_icon.png',
        width: 42,
        height: 42,
        fit: BoxFit.cover,
      ),
    );
    if (!extended) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Prati'),
              TextSpan(
                text: 'Case',
                style: TextStyle(color: PratiCaseColors.teal),
              ),
            ],
          ),
          style: TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.identifier,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String identifier;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PratiCaseColors.teal : PratiCaseColors.muted;
    final compact = PratiCaseResponsive.isCompactPhone(context);
    final itemHeight =
        (PratiCaseResponsive.bottomNavigationHeightForWidth(
                  MediaQuery.sizeOf(context).width,
                ) -
                20)
            .clamp(54.0, 62.0)
            .toDouble();
    return Expanded(
      child: Semantics(
        identifier: identifier,
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: () {
            if (!selected) PratiCaseHaptics.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          child: AnimatedContainer(
            duration: PratiCaseDurations.fast,
            curve: PratiCaseCurves.standard,
            height: itemHeight,
            margin: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
            decoration: BoxDecoration(
              color: selected
                  ? PratiCaseColors.teal.withValues(alpha: 0.11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
              border: selected
                  ? Border.all(
                      color: PratiCaseColors.teal.withValues(alpha: 0.10),
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: PratiCaseDurations.fast,
                  switchInCurve: PratiCaseCurves.standard,
                  switchOutCurve: PratiCaseCurves.exit,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.86,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    icon,
                    key: ValueKey(selected),
                    color: color,
                    size: compact ? 22 : 24,
                  ),
                ),
                SizedBox(height: compact ? 3 : PratiCaseSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: compact ? 10.5 : 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
