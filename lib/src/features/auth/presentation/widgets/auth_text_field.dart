import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

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
            color: PratiCaseColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          obscureText: _obscured,
          style: const TextStyle(
            color: PratiCaseColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF9AA5BC),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: PratiCaseColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 22,
            ),
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, color: PratiCaseColors.teal, size: 27),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF53647B),
                      size: 26,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: PratiCaseColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD3DAE4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: PratiCaseColors.teal,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD44747)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFD44747),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
