import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../widgets/auth_brand.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.repositoryConfigured,
    required this.onCreateAccount,
    required this.onLogin,
    super.key,
  });

  final bool repositoryConfigured;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthBrand(centered: false),
          const SizedBox(height: 32),
          Text(
            'OSCE’ye gerçek sınav gibi hazırlan.',
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 31,
              height: 1.06,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sanal hasta ile konuş, anamnez al, muayene planla ve performans karneni gör.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          const _OnboardingIllustration(),
          const SizedBox(height: 18),
          const _FeatureTile(
            icon: Icons.timer_rounded,
            title: 'Süreli OSCE istasyonları',
            body: 'Gerçek sınav temposunda pratik yap.',
          ),
          const _FeatureTile(
            icon: Icons.record_voice_over_rounded,
            title: 'Sanal hasta görüşmesi',
            body: 'Hikayeyi dinle, doğru soruları sor.',
          ),
          const _FeatureTile(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Rubrik tabanlı puanlama',
            body: 'Detaylı geri bildirimle gelişimini izle.',
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(label: 'Hesap Oluştur', onPressed: onCreateAccount),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: PratiCaseColors.teal,
              side: const BorderSide(color: PratiCaseColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Giriş Yap'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                repositoryConfigured
                    ? Icons.verified_user_rounded
                    : Icons.shield_outlined,
                size: 18,
                color: PratiCaseColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  repositoryConfigured
                      ? 'Medasi hesabınla güvenli şekilde devam et.'
                      : 'Medasi auth env gelene kadar güvenli demo akışı açık.',
                  style: textTheme.bodySmall,
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
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PratiCaseColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 26,
            bottom: 24,
            child: Icon(
              Icons.chat_bubble_rounded,
              color: PratiCaseColors.teal.withValues(alpha: 0.38),
              size: 42,
            ),
          ),
          Positioned(
            right: 28,
            bottom: 0,
            child: Icon(
              Icons.medical_services_rounded,
              color: PratiCaseColors.navy.withValues(alpha: 0.78),
              size: 132,
            ),
          ),
          Positioned(
            right: 30,
            top: 28,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: PratiCaseColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: PratiCaseColors.teal,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PratiCaseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PratiCaseColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: PratiCaseColors.teal.withValues(alpha: 0.1),
            child: Icon(icon, color: PratiCaseColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
