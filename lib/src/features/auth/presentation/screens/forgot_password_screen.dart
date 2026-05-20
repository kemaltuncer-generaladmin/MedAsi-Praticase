import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/auth_visuals.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    required this.repository,
    required this.onBack,
    required this.onCodeSent,
    super.key,
  });

  final AuthRepository repository;
  final VoidCallback onBack;
  final ValueChanged<String> onCodeSent;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  Timer? _timer;
  int _seconds = 45;
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.sendPasswordResetCode(_email.text);
      _startCountdown();
      setState(() => _sent = true);
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _seconds = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _sentView(context);

    return AuthScaffold(
      onBack: widget.onBack,
      topPadding: 78,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: AuthHeroIllustration(
                type: AuthHeroType.envelope,
                size: 210,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Şifremi mi unuttum?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: PratiCaseColors.navy,
                fontSize: 33,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'E-posta adresini gir, şifre sıfırlama bağlantısını gönderelim.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF465872),
                fontSize: 20,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 54),
            AuthTextField(
              label: 'E-posta',
              hintText: 'E-posta adresinizi girin',
              controller: _email,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 42),
            AuthPrimaryButton(
              label: 'Gönder',
              loading: _loading,
              onPressed: _send,
            ),
            const SizedBox(height: 28),
            Center(
              child: AuthLinkButton(
                label: 'Giriş ekranına dön',
                onPressed: widget.onBack,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sentView(BuildContext context) {
    return AuthScaffold(
      onBack: widget.onBack,
      topPadding: 78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AuthHeroIllustration(type: AuthHeroType.envelope, size: 222),
          ),
          const SizedBox(height: 36),
          Text(
            'E-posta gönderildi!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: PratiCaseColors.navy,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Şifre sıfırlama bağlantısını içeren bir e-posta gönderdik. Lütfen gelen kutunuzu kontrol edin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF465872),
              fontSize: 20,
              height: 1.36,
            ),
          ),
          const SizedBox(height: 42),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: PratiCaseColors.tealBright.withValues(
                    alpha: 0.18,
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: PratiCaseColors.teal,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-posta gelmedi mi?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: PratiCaseColors.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spam / Gereksiz klasörünü kontrol edebilir veya tekrar deneyebilirsin.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF23364F),
                          height: 1.38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          AuthPrimaryButton(
            label: _seconds > 0
                ? 'Tekrar Gönder (00:${_seconds.toString().padLeft(2, '0')})'
                : 'Tekrar Gönder',
            loading: _loading,
            onPressed: _seconds > 0 ? null : _send,
          ),
          const SizedBox(height: 32),
          Center(
            child: AuthLinkButton(
              label: 'Giriş ekranına dön',
              onPressed: widget.onBack,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
          ],
        ],
      ),
    );
  }
}
