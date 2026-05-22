import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
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
      showFooterText: false,
      topPadding: 28,
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LoginBrandHeader(),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PratiCaseColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PratiCaseColors.border),
                boxShadow: [
                  BoxShadow(
                    color: PratiCaseColors.navy.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'E-posta Adresi',
                    hintText: 'doktor@hastane.com',
                    controller: _email,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AuthTextField(
                          label: 'Şifre',
                          hintText: '••••••••',
                          controller: _password,
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: AuthValidators.password,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AuthLinkButton(
                      label: 'Şifremi Unuttum',
                      onPressed: widget.onForgotPassword,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AuthStatusCard(
                      message: _error!,
                      tone: AuthStatusTone.error,
                    ),
                  ],
                  const SizedBox(height: 14),
                  AuthPrimaryButton(
                    label: 'Giriş Yap',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),
                  const _DividerLabel(),
                  const SizedBox(height: 16),
                  const _ProviderButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: 'Google ile devam et',
                  ),
                  const SizedBox(height: 8),
                  const _ProviderButton(
                    icon: Icons.apple_rounded,
                    label: 'Apple ile devam et',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hesabın yok mu?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: PratiCaseColors.muted,
                    fontSize: 14,
                  ),
                ),
                AuthLinkButton(label: 'Kayıt Ol', onPressed: widget.onRegister),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: PratiCaseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PratiCaseColors.border),
            boxShadow: [
              BoxShadow(
                color: PratiCaseColors.navy.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            color: PratiCaseColors.teal,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hoş Geldiniz',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: PratiCaseColors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'PratiCase klinik simülasyonuna giriş yapın.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PratiCaseColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: PratiCaseColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'veya',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: PratiCaseColors.muted),
          ),
        ),
        const Expanded(child: Divider(color: PratiCaseColors.border)),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: PratiCaseColors.ink),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: PratiCaseColors.ink,
        side: const BorderSide(color: PratiCaseColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
