import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../widgets/auth_brand.dart';
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
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.repository.sendPasswordResetCode(_email.text);
      setState(() => _success = 'Kod gönderildi.');
      widget.onCodeSent(_email.text.trim());
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthBrand(),
            const SizedBox(height: 42),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFE9F6F4),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                'Şifreni sıfırla',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'E-posta adresini gir, sana sıfırlama kodu gönderelim.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 28),
            AuthTextField(
              label: 'E-posta',
              hintText: 'ornek@mail.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Kod Gönder',
              loading: _loading,
              onPressed: _send,
            ),
            const SizedBox(height: 16),
            Center(
              child: AuthLinkButton(
                label: 'Giriş ekranına dön',
                onPressed: widget.onBack,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              AuthStatusCard(
                title: 'Kod gönderildi!',
                message: 'Lütfen gelen kutunu kontrol et.',
                tone: AuthStatusTone.success,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
