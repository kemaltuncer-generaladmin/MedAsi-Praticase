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
    if (extended) {
      return _DesktopSideRail(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      );
    }
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

class _DesktopSideRail extends StatelessWidget {
  const _DesktopSideRail({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 252,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF07151F),
              PratiCaseColors.navy,
              PratiCaseColors.gradientStart,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: PratiCaseColors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: PratiCaseColors.navy.withValues(alpha: 0.22),
              blurRadius: 34,
              spreadRadius: -12,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RailPatternPainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DesktopRailBrand(),
                    const SizedBox(height: 28),
                    _DesktopRailItem(
                      selected: selectedIndex == 0,
                      icon: Icons.home_rounded,
                      label: 'Ana Sayfa',
                      onTap: () => onSelected(0),
                    ),
                    _DesktopRailItem(
                      selected: selectedIndex == 1,
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Cüzdan',
                      onTap: () => onSelected(1),
                    ),
                    _DesktopRailItem(
                      selected: selectedIndex == 2,
                      icon: Icons.assignment_rounded,
                      label: 'Sınavlar',
                      onTap: () => onSelected(2),
                    ),
                    _DesktopRailItem(
                      selected: selectedIndex == 3,
                      icon: Icons.trending_up_rounded,
                      label: 'Gelişim',
                      onTap: () => onSelected(3),
                    ),
                    _DesktopRailItem(
                      selected: selectedIndex == 4,
                      icon: Icons.person_rounded,
                      label: 'Profilim',
                      onTap: () => onSelected(4),
                    ),
                    const Spacer(),
                    const _RailFocusCard(),
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

class _DesktopRailBrand extends StatelessWidget {
  const _DesktopRailBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/auth/praticase_icon.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Prati'),
                TextSpan(
                  text: 'Case',
                  style: TextStyle(color: PratiCaseColors.tealBright),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PratiCaseColors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopRailItem extends StatelessWidget {
  const _DesktopRailItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? PratiCaseColors.navy
        : PratiCaseColors.white.withValues(alpha: 0.78);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressableScale(
        onTap: () {
          if (!selected) PratiCaseHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: PratiCaseDurations.fast,
          curve: PratiCaseCurves.standard,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [PratiCaseColors.white, Color(0xFFEAF8F6)],
                  )
                : null,
            color: selected
                ? null
                : PratiCaseColors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? PratiCaseColors.tealBright.withValues(alpha: 0.42)
                  : PratiCaseColors.white.withValues(alpha: 0.075),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PratiCaseColors.tealBright.withValues(alpha: 0.16),
                      blurRadius: 18,
                      spreadRadius: -5,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? PratiCaseColors.teal.withValues(alpha: 0.11)
                      : PratiCaseColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: contentColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailFocusCard extends StatelessWidget {
  const _RailFocusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PratiCaseColors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PratiCaseColors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PratiCaseColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: PratiCaseColors.goldBright,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'OSCE performans merkezi',
            style: TextStyle(
              color: PratiCaseColors.white,
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Anamnez, muayene, tetkik ve yönetim planını tek akışta izle.',
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.66),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = PratiCaseColors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 38), linePaint);
    }
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              PratiCaseColors.tealBright.withValues(alpha: 0.20),
              PratiCaseColors.tealBright.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.20, size.height * 0.08),
              radius: 180,
            ),
          );
    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.08), 180, glow);
  }

  @override
  bool shouldRepaint(covariant _RailPatternPainter oldDelegate) => false;
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
