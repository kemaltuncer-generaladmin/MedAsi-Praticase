import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

enum AuthStatusTone { success, warning, error, info }

class AuthStatusCard extends StatelessWidget {
  const AuthStatusCard({
    required this.message,
    this.title,
    this.tone = AuthStatusTone.info,
    super.key,
  });

  final String? title;
  final String message;
  final AuthStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      AuthStatusTone.success => (
        PratiCaseColors.successGreen,
        PratiCaseColors.successSurface,
        Icons.check_circle_outline_rounded,
      ),
      AuthStatusTone.warning => (
        PratiCaseColors.gold,
        PratiCaseColors.warningSurface,
        Icons.warning_amber_rounded,
      ),
      AuthStatusTone.error => (
        PratiCaseColors.errorRed,
        PratiCaseColors.errorSurface,
        Icons.error_outline_rounded,
      ),
      AuthStatusTone.info => (
        const Color(0xFF1D67D2),
        const Color(0xFFEAF4FF),
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.$1.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(colors.$3, color: colors.$1, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.$1,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                if (title != null) const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PratiCaseColors.slateBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
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
