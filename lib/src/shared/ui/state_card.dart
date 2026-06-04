import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_typography.dart';
import 'clinical_card.dart';

class StateCard extends StatelessWidget {
  const StateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.iconColor = PratiCaseColors.teal,
    this.action,
    super.key,
  });

  const StateCard.loading({
    this.title = 'Yükleniyor',
    this.body = 'Veriler yükleniyor...',
    super.key,
  }) : icon = Icons.hourglass_top_rounded,
       iconColor = PratiCaseColors.teal,
       action = null;

  const StateCard.error({
    this.title = 'Bir şeyler ters gitti',
    this.body = 'Bağlantı kurulamadı. Lütfen tekrar dene.',
    this.action,
    super.key,
  }) : icon = Icons.cloud_off_rounded,
       iconColor = PratiCaseColors.errorRed;

  const StateCard.empty({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  }) : iconColor = PratiCaseColors.teal;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Concentric accent ring — premium, sade, illustrasyon yok.
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.06),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.13),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PratiCaseTextStyles.cardTitle,
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: PratiCaseTextStyles.sectionSubtitle,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
