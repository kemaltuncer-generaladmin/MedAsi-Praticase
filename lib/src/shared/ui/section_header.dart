import 'package:flutter/material.dart';

import '../../app/theme/praticase_typography.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PratiCaseTextStyles.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle ?? '',
                  style: PratiCaseTextStyles.sectionSubtitle,
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PratiCaseTextStyles.pageTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: PratiCaseTextStyles.pageSubtitle),
        ],
      ],
    );
  }
}
