import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final activeVisual = onPressed != null || loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: activeVisual ? null : const Color(0xFFE2E7EF),
          borderRadius: BorderRadius.circular(12),
          gradient: activeVisual
              ? const LinearGradient(
                  colors: [PratiCaseColors.teal, PratiCaseColors.navy],
                )
              : null,
          boxShadow: activeVisual
              ? [
                  BoxShadow(
                    color: PratiCaseColors.navy.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: loading
                ? const SizedBox.square(
                    key: ValueKey('loading'),
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: activeVisual
                              ? Colors.white
                              : Color(0xFF718096),
                        ),
                      ),
                      if (showArrow) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, size: 22),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
