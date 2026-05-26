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
              ClipRRect(
                borderRadius: BorderRadius.circular(PratiCaseRadius.md),
                child: Image.asset(
                  'assets/auth/praticase_icon.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Prati'),
                    TextSpan(
                      text: 'Case',
                      style: TextStyle(color: PratiCaseColors.teal),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: PratiCaseColors.navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width * 0.62).clamp(210.0, 264.0).toDouble();
        final cardWidth = (width * 0.62).clamp(206.0, 250.0).toDouble();
        final cardHeight = (height * 0.80).clamp(168.0, 212.0).toDouble();
        final haloSize = (height * 0.76).clamp(160.0, 204.0).toDouble();
        return SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                height: height,
                decoration: BoxDecoration(
                  gradient: PratiCaseGradients.hero,
                  borderRadius: BorderRadius.circular(PratiCaseRadius.xl),
                ),
              ),
              Container(
                width: haloSize,
                height: haloSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PratiCaseColors.white.withValues(alpha: 0.06),
                ),
              ),
              Container(
                width: cardWidth,
                height: cardHeight,
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
      },
    );
  }
}
