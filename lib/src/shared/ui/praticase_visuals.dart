import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_motion.dart';
import '../../app/theme/praticase_tokens.dart';
import 'responsive.dart';

class PratiCaseSkeletonBlock extends StatelessWidget {
  const PratiCaseSkeletonBlock({
    this.width = double.infinity,
    this.height = 16,
    this.radius = PratiCaseRadius.md,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.72, end: 1),
      duration: PratiCaseDurations.showcase,
      curve: PratiCaseCurves.smooth,
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        child: child,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PratiCaseColors.surfaceContainerHighest.withValues(alpha: 0.82),
              PratiCaseColors.white,
              PratiCaseColors.surfaceContainerHighest.withValues(alpha: 0.68),
            ],
            stops: const [0, 0.52, 1],
          ),
        ),
      ),
    );
  }
}

class PratiCaseSkeletonCard extends StatelessWidget {
  const PratiCaseSkeletonCard({
    this.lines = 3,
    this.leading = true,
    this.height,
    super.key,
  });

  final int lines;
  final bool leading;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Container(
        constraints: BoxConstraints(minHeight: height ?? 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PratiCaseColors.white,
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          border: Border.all(color: PratiCaseColors.border),
          boxShadow: PratiCaseShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading) ...[
              const PratiCaseSkeletonBlock(
                width: 52,
                height: 52,
                radius: PratiCaseRadius.lg,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PratiCaseSkeletonBlock(width: 160, height: 18),
                  const SizedBox(height: 12),
                  for (var index = 0; index < lines; index++) ...[
                    PratiCaseSkeletonBlock(
                      width: index == lines - 1 ? 210 : double.infinity,
                      height: 13,
                      radius: PratiCaseRadius.sm,
                    ),
                    if (index != lines - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PratiCaseScreenSkeleton extends StatelessWidget {
  const PratiCaseScreenSkeleton({
    this.titleWidth = 220,
    this.heroHeight = 150,
    this.cardCount = 3,
    this.showSearch = false,
    super.key,
  });

  final double titleWidth;
  final double heroHeight;
  final int cardCount;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return PratiCaseResponsiveListView(
      padding: PratiCaseResponsive.pagePadding(context),
      children: [
        Row(
          children: const [
            PratiCaseSkeletonBlock(
              width: 44,
              height: 44,
              radius: PratiCaseRadius.md,
            ),
            SizedBox(width: 12),
            PratiCaseSkeletonBlock(width: 128, height: 26),
            Spacer(),
            PratiCaseSkeletonBlock(
              width: 44,
              height: 44,
              radius: PratiCaseRadius.pill,
            ),
          ],
        ),
        const SizedBox(height: 30),
        PratiCaseSkeletonBlock(width: titleWidth, height: 34),
        const SizedBox(height: 10),
        const PratiCaseSkeletonBlock(width: 280, height: 14),
        if (showSearch) ...[
          const SizedBox(height: 22),
          const PratiCaseSkeletonBlock(
            height: 62,
            radius: PratiCaseRadius.xl,
          ),
        ],
        const SizedBox(height: 24),
        PratiCaseSkeletonBlock(
          height: heroHeight,
          radius: PratiCaseRadius.xxl,
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < cardCount; index++) ...[
          PratiCaseSkeletonCard(lines: index.isEven ? 2 : 3),
          if (index != cardCount - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class PratiCaseInlineSkeleton extends StatelessWidget {
  const PratiCaseInlineSkeleton({
    this.cardCount = 3,
    this.heroHeight,
    super.key,
  });

  final int cardCount;
  final double? heroHeight;

  @override
  Widget build(BuildContext context) {
    return FadeSlideInList(
      children: [
        if (heroHeight != null)
          PratiCaseSkeletonBlock(
            height: heroHeight!,
            radius: PratiCaseRadius.xxl,
          ),
        for (var index = 0; index < cardCount; index++)
          PratiCaseSkeletonCard(lines: index.isEven ? 2 : 3),
      ],
    );
  }
}

class PratiCaseGroupedSection extends StatelessWidget {
  const PratiCaseGroupedSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Container(
        decoration: BoxDecoration(
          color: PratiCaseColors.white,
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          border: Border.all(color: PratiCaseColors.border),
          boxShadow: PratiCaseShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: PratiCaseColors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          PratiCaseRadius.md,
                        ),
                      ),
                      child: Icon(icon, color: PratiCaseColors.teal, size: 20),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: PratiCaseColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: PratiCaseColors.muted,
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, indent: 58, endIndent: 16),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class PratiCaseAnimatedNumber extends StatelessWidget {
  const PratiCaseAnimatedNumber({
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 850),
    super.key,
  });

  final num value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: PratiCaseCurves.overshoot,
      builder: (context, animated, _) {
        return Text('$prefix${animated.round()}$suffix', style: style);
      },
    );
  }
}
