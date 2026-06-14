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
    required this.onForgotPassword,
    required this.onRegister,
    required this.onSignedIn,
    this.onBack,
    super.key,
  });

  final AuthRepository repository;
  final VoidCallback? onBack;
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
        rememberMe: true,
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
      child: AuthCard(
        children: [
          const AuthScreenHeader(
            title: 'PratiCase\'e Hoş Geldiniz 👋',
            subtitle: 'MedAsi hesabınızla devam edin',
          ),
          const SizedBox(height: 24),
          const AuthEcosystemCallout(),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'E-posta',
                  hintText: 'ornek@email.com',
                  controller: _email,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: PratiCaseSpacing.lg),
                AuthTextField(
                  label: 'Şifre',
                  hintText: 'Şifrenizi girin',
                  controller: _password,
                  icon: Icons.lock_outline_rounded,
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
          const SizedBox(height: 26),
          const AuthDivider(),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Hesabın yok mu? ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PratiCaseColors.slateBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AuthLinkButton(label: 'Kayıt Ol', onPressed: widget.onRegister),
            ],
          ),
        ],
      ),
    );
  }
}
