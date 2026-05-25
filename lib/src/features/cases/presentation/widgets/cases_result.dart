part of '../cases_screen.dart';

class _ResultHero extends StatefulWidget {
  const _ResultHero({required this.result});

  final ExamResultSummary result;

  @override
  State<_ResultHero> createState() => _ResultHeroState();
}

class _ResultHeroState extends State<_ResultHero> {
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animated = true);
      PratiCaseHaptics.success();
    });
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.result.percentage;
    final scoreColor = percentage >= 80
        ? PratiCaseColors.successGreen
        : percentage >= 60
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    final endValue = widget.result.maxScore == 0
        ? 0.0
        : (widget.result.totalScore / widget.result.maxScore).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 36, 22, 30),
      decoration: const BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(PratiCaseRadius.xxl),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _animated ? endValue : 0),
                  duration: const Duration(milliseconds: 1100),
                  curve: PratiCaseCurves.overshoot,
                  builder: (context, value, _) {
                    return SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        backgroundColor: PratiCaseColors.white.withValues(
                          alpha: 0.18,
                        ),
                        color: scoreColor,
                        strokeCap: StrokeCap.round,
                      ),
                    );
                  },
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: _animated ? percentage.toDouble() : 0,
                  ),
                  duration: const Duration(milliseconds: 1100),
                  curve: PratiCaseCurves.overshoot,
                  builder: (context, value, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '%${value.round()}',
                          style: const TextStyle(
                            color: PratiCaseColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.result.totalScore}/${widget.result.maxScore}',
                          style: TextStyle(
                            color: PratiCaseColors.white.withValues(
                              alpha: 0.72,
                            ),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Klinik Başarı Puanı',
            style: TextStyle(
              color: PratiCaseColors.tealBright,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percentage >= 80
                ? 'Mükemmel bir teşhis süreci yönettiniz.'
                : '${widget.result.caseTitle} için gelişim alanların hazır.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PratiCaseColors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.scores});

  final List<ResultCategoryScore> scores;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const _CenteredState(
        icon: Icons.query_stats_rounded,
        title: 'Puan dağılımı yok',
        body: 'Değerlendirme dağılımı şu anda hazırlanamadı.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori Performansı',
            style: TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (final score in scores) ...[
            _ScoreBar(score: score),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.score});

  final ResultCategoryScore score;

  @override
  Widget build(BuildContext context) {
    final percent = score.maxScore == 0 ? 0.0 : score.score / score.maxScore;
    final barColor = percent >= 0.8
        ? PratiCaseColors.successGreen
        : percent >= 0.6
        ? PratiCaseColors.gold
        : PratiCaseColors.errorRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                score.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${score.score}/${score.maxScore}',
              style: TextStyle(
                color: barColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percent.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: PratiCaseCurves.overshoot,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: PratiCaseColors.border,
              color: barColor,
            ),
          ),
        ),
        if (score.title.toLowerCase().contains('yönetim') &&
            score.score == 0) ...[
          const SizedBox(height: 7),
          const Text(
            'Puanlanabilir bir yönetim adımı seçilmedi.',
            style: TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.onRetry,
    required this.retryLabel,
    required this.onReport,
  });

  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(retryLabel),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Detaylı Rapor'),
          ),
        ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        border: Border.all(color: PratiCaseColors.border),
        boxShadow: PratiCaseShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: PratiCaseColors.ink,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IdealApproachCard extends StatelessWidget {
  const _IdealApproachCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'İdeal Yaklaşım Özeti',
      child: Text(
        text.isEmpty
            ? 'Değerlendirme özeti hazırlanamadı; güçlü yönlerin ve gelişim '
                  'alanların son yanıtlarına göre yukarıda gösterildi.'
            : text,
        style: const TextStyle(
          color: PratiCaseColors.slateBlue,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
    );
  }
}
