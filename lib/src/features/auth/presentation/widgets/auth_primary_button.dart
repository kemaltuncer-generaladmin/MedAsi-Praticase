import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';

const _buttonStart = Color(0xFF1D67D2);
const _buttonEnd = Color(0xFF56A4F4);

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = false,
    this.pulse = false,
    this.identifier,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final bool pulse;
  final String? identifier;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: _enabled ? 1 : 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: _enabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_buttonStart, _buttonEnd],
                )
              : null,
          color: _enabled ? null : const Color(0xFFD5E2F0),
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: _buttonStart.withValues(alpha: pulse ? 0.26 : 0.18),
                    blurRadius: pulse ? 28 : 22,
                    spreadRadius: -8,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 52,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: loading
                      ? const SizedBox.square(
                          key: ValueKey('loading'),
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: PratiCaseColors.white,
                          ),
                        )
                      : Row(
                          key: ValueKey(label),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: PratiCaseColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                            if (showArrow) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: PratiCaseColors.white,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (identifier == null) return button;
    return Semantics(
      identifier: identifier,
      label: label,
      button: true,
      enabled: _enabled,
      child: button,
    );
  }
}
