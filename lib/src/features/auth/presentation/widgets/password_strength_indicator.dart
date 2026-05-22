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
      ('En az 1 büyük harf', _hasUppercase),
      ('En az 1 rakam', _hasNumber),
    ];
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
                      ? const Color(0xFF16A36C)
                      : PratiCaseColors.teal,
                  size: 30,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    item.$1,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF23364F),
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
