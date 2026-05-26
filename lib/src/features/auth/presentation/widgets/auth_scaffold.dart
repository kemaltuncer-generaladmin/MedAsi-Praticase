import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import 'auth_visuals.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.onBack,
    this.bottom,
    this.showFooterText = true,
    this.topPadding = 20,
    this.bottomPadding = 32,
    super.key,
  });

  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final bool showFooterText;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: PratiCaseColors.softSurface,
      body: Stack(
        children: [
          Positioned.fill(
            child: AuthBackground(showFooterText: showFooterText),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth >= 900
                    ? 520.0
                    : constraints.maxWidth >= 720
                    ? 460.0
                    : double.infinity;
                final horizontalPadding = constraints.maxWidth < 380
                    ? 16.0
                    : 20.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      children: [
                        SizedBox(
                          height: onBack == null ? 8 : 58,
                          child: onBack == null
                              ? null
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: PratiCaseColors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: PratiCaseShadows.card,
                                      ),
                                      child: IconButton(
                                        onPressed: onBack,
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                          color: PratiCaseColors.navy,
                                          size: 25,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              topPadding,
                              horizontalPadding,
                              bottomPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                child,
                                if (showFooterText && !keyboardOpen) ...[
                                  const SizedBox(height: 28),
                                  const _AuthTrustFooter(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (bottom != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: bottom,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTrustFooter extends StatelessWidget {
  const _AuthTrustFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PratiCaseColors.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: PratiCaseColors.teal,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Güvenli Medasi hesabınla devam et',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PratiCaseColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
