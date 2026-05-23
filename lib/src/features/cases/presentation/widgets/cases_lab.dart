part of '../cases_screen.dart';

class _LabResultHero extends StatelessWidget {
  const _LabResultHero({required this.title, required this.measuredAt});

  final String title;
  final DateTime? measuredAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: PratiCaseGradients.hero,
        borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
        boxShadow: [
          BoxShadow(
            color: PratiCaseColors.navy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: PratiCaseColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
            ),
            child: const Icon(
              Icons.biotech_outlined,
              color: PratiCaseColors.tealBright,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  measuredAt == null
                      ? 'İstenen tetkik sonucu'
                      : 'Ölçüm: ${_shortDateTime(measuredAt!)}',
                  style: TextStyle(
                    color: PratiCaseColors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabParametersCard extends StatelessWidget {
  const _LabParametersCard({required this.parameters});

  final List<LabParameter> parameters;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parametreler',
      child: Column(
        children: [
          if (parameters.isEmpty)
            const Text('Bu laboratuvar sonucu için parametre tanımlanmadı.')
          else
            for (final item in parameters) ...[
              _LabParameterTile(parameter: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LabParameterTile extends StatelessWidget {
  const _LabParameterTile({required this.parameter});

  final LabParameter parameter;

  @override
  Widget build(BuildContext context) {
    final abnormal = _labParameterAbnormal(parameter.status);
    final color = abnormal ? PratiCaseColors.errorRed : PratiCaseColors.teal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: abnormal
            ? PratiCaseColors.errorRed.withValues(alpha: 0.06)
            : PratiCaseColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(PratiCaseRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parameter.name,
                  style: const TextStyle(
                    color: PratiCaseColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (parameter.referenceRange.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    parameter.referenceRange,
                    style: const TextStyle(
                      color: PratiCaseColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  parameter.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (parameter.status.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    parameter.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
