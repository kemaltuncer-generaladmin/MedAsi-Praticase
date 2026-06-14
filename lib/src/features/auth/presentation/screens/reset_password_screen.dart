import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/otp_input.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    required this.repository,
    required this.email,
    required this.onBack,
    required this.onPasswordUpdated,
    super.key,
  });

  final AuthRepository repository;
  final String email;
  final VoidCallback onBack;
  final VoidCallback onPasswordUpdated;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String _code = '';
  bool _loading = false;
  String? _error;
  bool _updated = false;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_code.length != 6) {
      setState(() => _error = '6 haneli doğrulama kodunu gir.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.resetPassword(
        email: widget.email,
        code: _code,
        newPassword: _password.text,
      );
      setState(() => _updated = true);
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: _updated ? null : widget.onBack,
      child: _updated ? _successCard(context) : _passwordCard(context),
    );
  }

  Widget _passwordCard(BuildContext context) {
    return AuthCard(
      children: [
        const AuthScreenHeader(
          title: 'Yeni Şifre',
          subtitle: 'Tek kriter: en az 8 karakter',
          center: true,
        ),
        const SizedBox(height: 24),
        const Text(
          'E-posta doğrulama kodu',
          style: TextStyle(
            color: Color(0xFF3E5E86),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        OtpInput(onChanged: (value) => _code = value),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: 'Yeni Şifre',
                hintText: 'Şifrenizi girin',
                controller: _password,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.password,
              ),
              const SizedBox(height: PratiCaseSpacing.lg),
              AuthTextField(
                label: 'Şifre Tekrar',
                hintText: 'Şifrenizi tekrar girin',
                controller: _repeat,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: (value) {
                  if (value != _password.text) return 'Şifreler eşleşmiyor.';
                  return AuthValidators.password(value);
                },
              ),
            ],
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
          label: 'Şifreyi Güncelle',
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _successCard(BuildContext context) {
    return AuthCard(
      children: [
        const _SuccessMark(),
        const SizedBox(height: 22),
        const AuthScreenHeader(
          title: 'MedAsi Ailesine Hoş Geldiniz! 🎉',
          subtitle:
              'Hesabınız hazır. Artık ekosistemin tamamı parmaklarınızın ucunda.',
          center: true,
        ),
        const SizedBox(height: 20),
        Text(
          'Aynı hesapla Qlinik, PratiCase ve SourceBase\'e tek dokunuşla geçiş yapabilirsiniz.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: PratiCaseColors.slateBlue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'PratiCase\'e Başla',
          onPressed: widget.onPasswordUpdated,
        ),
      ],
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1D67D2), Color(0xFF56A4F4)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D67D2).withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          color: PratiCaseColors.white,
          size: 42,
        ),
      ),
    );
  }
}
