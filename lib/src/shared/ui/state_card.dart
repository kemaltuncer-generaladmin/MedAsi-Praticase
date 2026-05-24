import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
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
    this.body = 'Canlı veri hazırlanıyor.',
    super.key,
  }) : icon = Icons.hourglass_top_rounded,
       iconColor = PratiCaseColors.teal,
       action = null;

  const StateCard.error({
    this.title = 'Bir şeyler ters gitti',
    this.body = 'Canlı veri bağlantısı kurulamadı.',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PratiCaseColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64728A),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
