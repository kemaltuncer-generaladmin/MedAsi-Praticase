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
import '../widgets/password_strength_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.repository,
    required this.onBack,
    required this.onLogin,
    required this.onRegistered,
    super.key,
  });

  final AuthRepository repository;
  final VoidCallback onBack;
  final VoidCallback onLogin;
  final void Function(String email, String fullName) onRegistered;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _error = 'Kullanım şartlarını kabul etmelisin.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.registerWithEmail(
        fullName: _fullName.text,
        email: _email.text,
        password: _password.text,
      );
      widget.onRegistered(_email.text.trim(), _fullName.text.trim());
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
            const SizedBox(height: 30),
            Text(
              'PratiCase hesabını oluştur',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'OSCE istasyonlarını çözmeye başla.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            AuthTextField(
              label: 'Ad Soyad',
              hintText: 'İpek Yılmaz',
              controller: _fullName,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.fullName,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'E-posta',
              hintText: 'ornek@mail.com',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Şifre',
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Şifre Tekrar',
              controller: _repeatPassword,
              obscureText: true,
              validator: (value) {
                if (value != _password.text) return 'Şifreler eşleşmiyor.';
                return AuthValidators.password(value);
              },
            ),
            const SizedBox(height: 14),
            PasswordStrengthIndicator(password: _password.text),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: PratiCaseColors.teal,
              title: Text(
                'Kullanım şartlarını okudum ve kabul ediyorum.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            AuthPrimaryButton(
              label: 'Kayıt Ol',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Zaten hesabın var mı?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AuthLinkButton(label: 'Giriş yap', onPressed: widget.onLogin),
              ],
            ),
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
