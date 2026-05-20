import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/auth_visuals.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.resetPassword(
        email: widget.email,
        code: '',
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
    if (_updated) return _successView(context);

    return AuthScaffold(
      onBack: widget.onBack,
      topPadding: 54,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: AuthHeroIllustration(type: AuthHeroType.lock, size: 196),
            ),
            const SizedBox(height: 26),
            Text(
              'Yeni şifre belirle',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: PratiCaseColors.navy,
                fontSize: 35,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Yeni şifreni belirle ve hesabına güvenle devam et.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF465872),
                fontSize: 20,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 44),
            AuthTextField(
              label: 'Yeni şifre',
              hintText: 'Yeni şifrenizi girin',
              controller: _password,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 24),
            AuthTextField(
              label: 'Yeni şifre tekrar',
              hintText: 'Yeni şifrenizi tekrar girin',
              controller: _repeat,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: (value) {
                if (value != _password.text) return 'Şifreler eşleşmiyor.';
                return AuthValidators.password(value);
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Şifre gereksinimleri:',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: PratiCaseColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            PasswordStrengthIndicator(password: _password.text),
            const SizedBox(height: 34),
            AuthPrimaryButton(
              label: 'Şifreyi Güncelle',
              loading: _loading,
              onPressed: _submit,
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

  Widget _successView(BuildContext context) {
    return AuthScaffold(
      topPadding: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: AuthHeroIllustration(type: AuthHeroType.success, size: 220),
          ),
          const SizedBox(height: 58),
          Text(
            'Şifre güncellendi!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: PratiCaseColors.navy,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Şifren başarıyla güncellendi.\nGiriş yaparak devam edebilirsin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF465872),
              fontSize: 21,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 74),
          AuthPrimaryButton(
            label: 'Giriş Ekranına Dön',
            onPressed: widget.onPasswordUpdated,
          ),
        ],
      ),
    );
  }
}
