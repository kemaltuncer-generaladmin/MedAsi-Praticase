import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({required this.password, super.key});

  final String password;

  bool get _hasMinLength => password.length >= 8;
  bool get _hasUppercase => RegExp('[A-ZÇĞİÖŞÜ]').hasMatch(password);
  bool get _hasNumber => RegExp('[0-9]').hasMatch(password);

  @override
  Widget build(BuildContext context) {
    final items = [
      ('En az 8 karakter', _hasMinLength),
      ('Bir büyük harf', _hasUppercase),
      ('Bir rakam', _hasNumber),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    item.$2 ? Icons.check_rounded : Icons.circle_outlined,
                    color: item.$2
                        ? PratiCaseColors.teal
                        : PratiCaseColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
