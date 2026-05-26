import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_visuals.dart';
import '../widgets/otp_input.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.repository,
    required this.email,
    required this.fullName,
    required this.onBack,
    required this.onVerified,
    super.key,
  });

  final AuthRepository repository;
  final String email;
  final String fullName;
  final VoidCallback onBack;
  final VoidCallback onVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  String _code = '';
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = '6 haneli kodu gir.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.repository.verifyEmailCode(email: widget.email, code: _code);
      widget.onVerified();
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _success = null;
    });
    try {
      await widget.repository.resendEmailVerification(widget.email);
      _startResendCooldown();
      setState(() => _success = 'Yeni kod gönderildi.');
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendSeconds = 45;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: widget.onBack,
      topPadding: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthWordmark(width: 224),
          const SizedBox(height: 10),
          const Text(
            'OSCE • Sözlü • Teorik',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PratiCaseColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 30),
          const Center(
            child: AuthHeroIllustration(type: AuthHeroType.envelope, size: 124),
          ),
          const SizedBox(height: 24),
          Text(
            'E-postanı doğrula',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: PratiCaseColors.navy,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Güvenliğin için, 6 haneli doğrulama kodunu ',
                ),
                TextSpan(
                  text: widget.email.isEmpty ? 'ornek@mail.com' : widget.email,
                  style: const TextStyle(
                    color: PratiCaseColors.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: ' adresine gönderdik.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF465872),
              fontSize: 17,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            decoration: BoxDecoration(
              color: PratiCaseColors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: PratiCaseColors.navy.withValues(alpha: 0.07),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthStatusCard(
                  title: 'Kod gönderilen e-posta',
                  message: widget.email.isEmpty
                      ? 'ornek@mail.com'
                      : widget.email,
                  tone: AuthStatusTone.info,
                ),
                const SizedBox(height: 24),
                OtpInput(onChanged: (value) => _code = value),
                const SizedBox(height: 28),
                AuthPrimaryButton(
                  label: 'Doğrulamayı Tamamla',
                  loading: _loading,
                  onPressed: _verify,
                ),
                const SizedBox(height: 18),
                Center(
                  child: AuthLinkButton(
                    label: _resendSeconds > 0
                        ? 'Kodu tekrar gönder (00:${_resendSeconds.toString().padLeft(2, '0')})'
                        : 'Kodu tekrar gönder',
                    onPressed: _resendSeconds > 0 ? null : _resend,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
          ],
          if (_success != null) ...[
            const SizedBox(height: 16),
            AuthStatusCard(message: _success!, tone: AuthStatusTone.success),
          ],
        ],
      ),
    );
  }
}
