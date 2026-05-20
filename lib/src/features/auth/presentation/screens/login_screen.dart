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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showFooterText: true,
      topPadding: 34,
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthLogoBlock(),
            const SizedBox(height: 58),
            Text(
              'Hoş geldin!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: PratiCaseColors.navy,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Devam etmek için hesabına giriş yap.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF465872),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 50),
            AuthTextField(
              label: 'E-posta',
              hintText: 'E-posta adresinizi girin',
              controller: _email,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 24),
            AuthTextField(
              label: 'Şifre',
              hintText: 'Şifrenizi girin',
              controller: _password,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AuthLinkButton(
                label: 'Şifremi unuttum?',
                onPressed: widget.onForgotPassword,
              ),
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: 'Giriş Yap',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hesabın yok mu?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF465872),
                  ),
                ),
                AuthLinkButton(label: 'Kayıt ol', onPressed: widget.onRegister),
              ],
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
}
