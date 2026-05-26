import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_motion.dart';
import '../../app/theme/praticase_tokens.dart';
import 'responsive.dart';

/// Sürekli akan shimmer gradient'le yükleme hissini güçlendiren skeleton
/// bloğu. Statik fade yerine soldan sağa kayan ince parlaklık şeridi
/// kullanır — premium SaaS / fintech standartına yakın.
class PratiCaseSkeletonBlock extends StatefulWidget {
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
  State<PratiCaseSkeletonBlock> createState() => _PratiCaseSkeletonBlockState();
}

class _PratiCaseSkeletonBlockState extends State<PratiCaseSkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // -1 → 1 doğrusal hareket: shimmer çubuk soldan sağa kayar.
            final shift = _controller.value * 2 - 1;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + shift, 0),
                  end: Alignment(0 + shift, 0),
                  colors: [
                    PratiCaseColors.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    PratiCaseColors.white.withValues(alpha: 0.92),
                    PratiCaseColors.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                color: PratiCaseColors.surfaceContainerHighest
                    .withValues(alpha: 0.55),
              ),
            );
          },
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
          border: Border.all(
            color: PratiCaseColors.border.withValues(alpha: 0.78),
          ),
          boxShadow: PratiCaseShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: PratiCaseColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          PratiCaseRadius.md,
                        ),
                        border: Border.all(
                          color:
                              PratiCaseColors.teal.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Icon(icon, color: PratiCaseColors.teal, size: 19),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: PratiCaseColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: PratiCaseColors.muted,
                              fontSize: 12,
                              height: 1.4,
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
                Divider(
                  height: 1,
                  thickness: 1,
                  color: PratiCaseColors.border.withValues(alpha: 0.55),
                  indent: 60,
                  endIndent: 16,
                ),
              children[index],
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// 0'dan hedef değere doğru sayan animasyonlu sayı.
///
/// [formatter] verilirse her frame'de o uygulanır (örn. K/M kısaltma,
/// para formatı). [maxLines]/[textAlign] alt-Text widget'ı için
/// FittedBox + tek satır taşma kontrolü sağlar.
class PratiCaseAnimatedNumber extends StatelessWidget {
  const PratiCaseAnimatedNumber({
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 850),
    this.curve = PratiCaseCurves.overshoot,
    this.formatter,
    this.maxLines = 1,
    this.textAlign,
    super.key,
  });

  final num value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String Function(double value)? formatter;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animated, _) {
        final body = formatter != null
            ? formatter!(animated)
            : animated.round().toString();
        return Text(
          '$prefix$body$suffix',
          style: style,
          maxLines: maxLines,
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
