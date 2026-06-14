import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
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
    _resendSeconds = 59;
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
      child: AuthCard(
        children: [
          const AuthScreenHeader(
            title: 'E-posta Doğrulama',
            subtitle: '6 haneli doğrulama kodu gönderildi',
            center: true,
          ),
          const SizedBox(height: 18),
          AuthStatusCard(
            title: _displayEmail,
            message: 'Kod spam klasörünüzde olabilir.',
            tone: AuthStatusTone.info,
          ),
          const SizedBox(height: 24),
          OtpInput(onChanged: (value) => _code = value),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(top: PratiCaseSpacing.lg),
                    child: AuthStatusCard(
                      message: _error!,
                      tone: AuthStatusTone.error,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_success != null) ...[
            const SizedBox(height: 16),
            AuthStatusCard(message: _success!, tone: AuthStatusTone.success),
          ],
          const SizedBox(height: 26),
          AuthPrimaryButton(
            label: 'Doğrula',
            loading: _loading,
            onPressed: _verify,
          ),
          const SizedBox(height: 12),
          Center(
            child: AuthLinkButton(
              label: _resendSeconds > 0
                  ? 'Yeniden gönder (${_resendSeconds}s)'
                  : 'Yeniden gönder',
              onPressed: _resendSeconds > 0 ? null : _resend,
            ),
          ),
        ],
      ),
    );
  }

  String get _displayEmail =>
      widget.email.isEmpty ? 'do•••@medasi.com.tr' : widget.email;
}
