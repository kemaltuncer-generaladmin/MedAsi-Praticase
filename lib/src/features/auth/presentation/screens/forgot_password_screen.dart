import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';

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
    return AuthScaffold(
      onBack: widget.onBack,
      child: _sent ? _sentCard(context) : _requestCard(context),
    );
  }

  Widget _requestCard(BuildContext context) {
    return AuthCard(
      children: [
        const AuthScreenHeader(
          title: 'Şifre Sıfırlama',
          subtitle: 'E-postanıza doğrulama kodu gönderilecek',
        ),
        const SizedBox(height: 26),
        Form(
          key: _formKey,
          child: AuthTextField(
            label: 'Kayıtlı E-posta Adresi',
            hintText: 'ornek@email.com',
            controller: _email,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: AuthValidators.email,
          ),
        ),
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
        const SizedBox(height: 26),
        AuthPrimaryButton(
          label: 'Kod Gönder',
          loading: _loading,
          onPressed: _send,
        ),
        const SizedBox(height: 18),
        Center(
          child: AuthLinkButton(
            label: 'Giriş ekranına dön',
            onPressed: widget.onBack,
          ),
        ),
      ],
    );
  }

  Widget _sentCard(BuildContext context) {
    return AuthCard(
      children: [
        const AuthScreenHeader(
          title: 'Kod Doğrulama',
          subtitle: '6 haneli doğrulama kodu gönderildi',
          center: true,
        ),
        const SizedBox(height: 18),
        AuthStatusCard(
          title: _email.text.trim(),
          message: 'Kod spam klasörünüzde olabilir.',
          tone: AuthStatusTone.info,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Yeni Şifreye Devam Et',
          onPressed: () => widget.onCodeSent(_email.text.trim()),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: _seconds > 0
              ? 'Yeniden gönder (${_seconds}s)'
              : 'Yeniden gönder',
          loading: _loading,
          onPressed: _seconds > 0 ? null : _send,
        ),
        const SizedBox(height: 18),
        Center(
          child: AuthLinkButton(
            label: 'Giriş ekranına dön',
            onPressed: widget.onBack,
          ),
        ),
      ],
    );
  }
}
