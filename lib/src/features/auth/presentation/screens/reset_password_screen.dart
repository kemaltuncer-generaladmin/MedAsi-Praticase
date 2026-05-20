import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_brand.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/otp_input.dart';
import '../widgets/password_strength_indicator.dart';

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
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

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
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthBrand(),
            const SizedBox(height: 34),
            Text(
              'Yeni şifre oluştur',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Hesabın için güvenli bir şifre belirle.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Text(
              'Doğrulama Kodu',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            OtpInput(onChanged: (value) => _code = value),
            const SizedBox(height: 18),
            AuthTextField(
              label: 'Yeni Şifre',
              controller: _password,
              obscureText: true,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _password.text.length >= 12
                  ? 1
                  : (_password.text.length / 12).clamp(0.08, 1),
              minHeight: 4,
              color: PratiCaseColors.teal,
              backgroundColor: PratiCaseColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Yeni Şifre Tekrar',
              controller: _repeat,
              obscureText: true,
              validator: (value) {
                if (value != _password.text) return 'Şifreler eşleşmiyor.';
                return AuthValidators.password(value);
              },
            ),
            const SizedBox(height: 14),
            PasswordStrengthIndicator(password: _password.text),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Şifreyi Güncelle',
              loading: _loading,
              onPressed: _submit,
            ),
            if (_updated) ...[
              const SizedBox(height: 18),
              AuthStatusCard(
                title: 'Şifren güncellendi!',
                message:
                    'Yeni şifrenle giriş yaparak pratiğine devam edebilirsin.',
                tone: AuthStatusTone.success,
              ),
              Center(
                child: AuthLinkButton(
                  label: 'Giriş Yap',
                  onPressed: widget.onPasswordUpdated,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
            ],
          ],
        ),
      ),
    );
  }
}
