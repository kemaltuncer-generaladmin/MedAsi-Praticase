import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import 'auth_visuals.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.onBack,
    this.bottom,
    this.showFooterText = true,
    this.topPadding = 20,
    this.bottomPadding = 190,
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
    return Scaffold(
      backgroundColor: PratiCaseColors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: AuthBackground(showFooterText: showFooterText),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth >= 720
                    ? 430.0
                    : double.infinity;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      children: [
                        SizedBox(
                          height: onBack == null ? 8 : 52,
                          child: onBack == null
                              ? null
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    onPressed: onBack,
                                    padding: const EdgeInsets.only(left: 18),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: PratiCaseColors.navy,
                                      size: 28,
                                    ),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              32,
                              topPadding,
                              32,
                              bottomPadding,
                            ),
                            child: child,
                          ),
                        ),
                        if (bottom != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
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
