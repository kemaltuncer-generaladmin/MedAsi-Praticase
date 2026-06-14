import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({required this.password, super.key});

  final String password;

  bool get _hasMinLength => password.length >= 8;

  @override
  Widget build(BuildContext context) {
    final items = [('Tek kriter: en az 8 karakter', _hasMinLength)];
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.check_rounded,
                  color: item.$2
                      ? PratiCaseColors.successGreen
                      : PratiCaseColors.teal,
                  size: 30,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    item.$1,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: PratiCaseColors.slateBlue,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
