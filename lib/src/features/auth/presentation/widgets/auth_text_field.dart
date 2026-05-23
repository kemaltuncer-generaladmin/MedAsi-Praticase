import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';

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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: PratiCaseColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: PratiCaseSpacing.sm),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          obscureText: _obscured,
          style: const TextStyle(
            color: PratiCaseColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: PratiCaseColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: PratiCaseSpacing.lg,
              vertical: PratiCaseSpacing.lg,
            ),
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, color: PratiCaseColors.muted, size: 20),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(
                color: PratiCaseColors.teal,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(color: PratiCaseColors.errorRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              borderSide: const BorderSide(
                color: PratiCaseColors.errorRed,
                width: 1.5,
              ),
            ),
            errorStyle: const TextStyle(
              color: PratiCaseColors.errorRed,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
