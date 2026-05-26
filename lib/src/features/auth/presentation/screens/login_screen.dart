import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';
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
  final ValueChanged<AuthUser> onSignedIn;

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
      final user = await widget.repository.signInWithEmail(
        email: _email.text,
        password: _password.text,
      );
      widget.onSignedIn(user);
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
              padding: const EdgeInsets.all(PratiCaseSpacing.xl),
              decoration: BoxDecoration(
                color: PratiCaseColors.white,
                borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
                border: Border.all(
                  color: PratiCaseColors.border.withValues(alpha: 0.86),
                ),
                boxShadow: PratiCaseShadows.card,
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
                  const SizedBox(height: PratiCaseSpacing.lg),
                  AuthTextField(
                    label: 'Şifre',
                    hintText: '••••••••',
                    controller: _password,
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: AuthValidators.password,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AuthLinkButton(
                      label: 'Şifremi Unuttum',
                      onPressed: widget.onForgotPassword,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(
                              bottom: PratiCaseSpacing.md,
                            ),
                            child: AuthStatusCard(
                              message: _error!,
                              tone: AuthStatusTone.error,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: PratiCaseSpacing.md),
                  AuthPrimaryButton(
                    identifier: 'cta.login-submit',
                    label: 'Giriş Yap',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PratiCaseSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hesabın yok mu?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PratiCaseColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              child: Image.asset(
                'assets/auth/praticase_icon.png',
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Prati'),
                  TextSpan(
                    text: 'Case',
                    style: TextStyle(color: PratiCaseColors.teal),
                  ),
                ],
              ),
              style: TextStyle(
                color: PratiCaseColors.navy,
                fontSize: 31,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Text(
          'Hesabına Giriş Yap',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: PratiCaseColors.navy,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'PratiCase klinik simülasyonuna giriş yapın.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PratiCaseColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
