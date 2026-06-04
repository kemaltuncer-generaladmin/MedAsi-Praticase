import 'package:flutter/material.dart';

import '../../app/theme/praticase_colors.dart';
import '../../app/theme/praticase_motion.dart';
import '../../app/theme/praticase_tokens.dart';
import '../../app/theme/praticase_typography.dart';

class PratiCaseFlowActionButton extends StatelessWidget {
  const PratiCaseFlowActionButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.identifier = 'cta.flow-action',
    this.height = 52,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final String identifier;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      identifier: identifier,
      button: true,
      label: label,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: PratiCaseDurations.fast,
        curve: PratiCaseCurves.standard,
        opacity: enabled ? 1 : 0.56,
        child: PressableScale(
          scale: 0.96,
          onTap: onPressed,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: enabled ? PratiCaseGradients.action : null,
                color: enabled ? null : PratiCaseColors.border,
                borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                boxShadow: enabled ? PratiCaseShadows.primaryCta : null,
              ),
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: PratiCaseColors.white,
                  disabledForegroundColor: PratiCaseColors.muted,
                  textStyle: PratiCaseTextStyles.cta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PratiCaseRadius.pill),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
