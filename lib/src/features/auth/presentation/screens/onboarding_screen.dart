import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
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
      topPadding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monitor_heart_rounded,
                color: PratiCaseColors.tealBright,
                size: 36,
              ),
              const SizedBox(width: 8),
              Text(
                'PratiCase',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: PratiCaseColors.gradientStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const _OnboardingIllustration(),
          const SizedBox(height: 34),
          Text(
            'Klinik Akıl Yürütme Becerini Geliştir',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: PratiCaseColors.ink,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gerçekçi vaka simülasyonları ile OSCE sınavlarına güvenle hazırlan.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: PratiCaseColors.slateBlue,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 54),
          AuthPrimaryButton(label: 'Başla', onPressed: onCreateAccount),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Zaten bir hesabın var mı?',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: PratiCaseColors.muted),
              ),
              TextButton(
                onPressed: onLogin,
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    color: PratiCaseColors.teal,
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
            width: 245,
            height: 245,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PratiCaseColors.tealBright.withValues(alpha: 0.16),
                  PratiCaseColors.teal.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(
            width: 256,
            height: 256,
            child: Container(
              decoration: BoxDecoration(
                color: PratiCaseColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PratiCaseColors.border),
                boxShadow: [
                  BoxShadow(
                    color: PratiCaseColors.navy.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/auth/onboarding_clinical_tablet.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
