import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../widgets/auth_brand.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.repository,
    required this.onBack,
    required this.onForgotPassword,
    required this.onRegister,
    required this.onSignedIn,
    super.key,
  });

  final AuthRepository repository;
  final VoidCallback onBack;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.repository.signInWithEmail(
        email: _email.text,
        password: _password.text,
      );
      widget.onSignedIn();
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.repository.signInWithGoogle();
      if (!widget.repository.isConfigured) {
        widget.onSignedIn();
      } else {
        setState(() => _info = 'Google giriş ekranına yönlendiriliyorsun.');
      }
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
            const SizedBox(height: 36),
            Text(
              'Tekrar hoş geldin',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Bugünkü OSCE pratiğine devam et.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            AuthTextField(
              label: 'E-posta',
              hintText: 'ornek@mail.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Şifre',
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: AuthValidators.password,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AuthLinkButton(
                label: 'Şifremi unuttum',
                onPressed: widget.onForgotPassword,
              ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Giriş Yap',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'veya',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _google,
              icon: const Text(
                'G',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              label: const Text('Google ile devam et'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hesabın yok mu?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AuthLinkButton(label: 'Kayıt ol', onPressed: widget.onRegister),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              AuthStatusCard(message: _info!, tone: AuthStatusTone.success),
            ],
          ],
        ),
      ),
    );
  }
}
