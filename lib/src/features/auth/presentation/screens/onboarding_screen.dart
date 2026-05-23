import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onCreateAccount,
    required this.onLogin,
    super.key,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showFooterText: false,
      topPadding: PratiCaseSpacing.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: PratiCaseSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monitor_heart_rounded,
                color: PratiCaseColors.tealBright,
                size: 32,
              ),
              const SizedBox(width: PratiCaseSpacing.sm),
              Text(
                'PratiCase',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: PratiCaseColors.gradientStart,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: PratiCaseSpacing.xxxl),
          const _OnboardingIllustration(),
          const SizedBox(height: PratiCaseSpacing.xxxl),
          Text(
            'Klinik Akıl Yürütme Becerini Geliştir',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: PratiCaseColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: PratiCaseSpacing.md),
          Text(
            'Gerçekçi vaka simülasyonları ile OSCE sınavlarına güvenle hazırlan.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: PratiCaseColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: PratiCaseSpacing.xxxl + PratiCaseSpacing.xxl),
          AuthPrimaryButton(
            identifier: 'cta.onboarding-start',
            label: 'Başla',
            onPressed: onCreateAccount,
            showArrow: true,
          ),
          const SizedBox(height: PratiCaseSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Zaten bir hesabın var mı?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PratiCaseColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: onLogin,
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    color: PratiCaseColors.teal,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 264,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 264,
            decoration: BoxDecoration(
              gradient: PratiCaseGradients.hero,
              borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
            ),
          ),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PratiCaseColors.white.withValues(alpha: 0.06),
            ),
          ),
          Container(
            width: 240,
            height: 210,
            decoration: BoxDecoration(
              color: PratiCaseColors.white,
              borderRadius: BorderRadius.circular(PratiCaseRadius.lg),
              boxShadow: PratiCaseShadows.floating,
            ),
            padding: const EdgeInsets.all(PratiCaseSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              child: Image.asset(
                'assets/auth/onboarding_clinical_tablet.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
