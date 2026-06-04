import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_tokens.dart';

class PratiCaseSearchField extends StatelessWidget {
  const PratiCaseSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 8, right: 4),
          child: Icon(Icons.search_rounded, color: PratiCaseColors.navy),
        ),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Aramayı temizle',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        contentPadding: const EdgeInsets.symmetric(vertical: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          borderSide: const BorderSide(color: PratiCaseColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.6,
          ),
        ),
      ),
    );
  }
}
