import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

class AuthLinkButton extends StatelessWidget {
  const AuthLinkButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: PratiCaseColors.teal),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
