import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = false,
    this.identifier,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final activeVisual = onPressed != null || loading;
    final core = SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: activeVisual ? null : PratiCaseColors.border,
          borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
          gradient: activeVisual ? PratiCaseGradients.action : null,
          boxShadow: activeVisual
              ? [
                  BoxShadow(
                    color: PratiCaseColors.teal.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: -6,
                    offset: const Offset(0, 14),
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
              borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
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
                      color: PratiCaseColors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              color: activeVisual
                                  ? PratiCaseColors.white
                                  : PratiCaseColors.muted,
                            ),
                          ),
                        ),
                      ),
                      if (showArrow) ...[
                        const SizedBox(width: PratiCaseSpacing.sm),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
    if (identifier == null) return core;
    return Semantics(
      identifier: identifier,
      button: true,
      label: label,
      container: true,
      child: core,
    );
  }
}
