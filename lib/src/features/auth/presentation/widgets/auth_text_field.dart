import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_typography.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.obscureText = false,
    this.icon,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool obscureText;
  final IconData? icon;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: PratiCaseTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          obscureText: _obscured,
          style: PratiCaseTextStyles.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, color: PratiCaseColors.slateBlue, size: 22),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: PratiCaseColors.muted,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
