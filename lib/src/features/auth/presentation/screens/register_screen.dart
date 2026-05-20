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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  bool _acceptedTerms = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(
        () => _error =
            'Kullanım koşulları ve gizlilik politikasını kabul etmelisin.',
      );
      return;
    }
    final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'
        .trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.registerWithEmail(
        fullName: fullName,
        email: _email.text,
        password: _password.text,
      );
      widget.onRegistered(_email.text.trim(), fullName);
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
      topPadding: 18,
      bottomPadding: 138,
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthWordmark(width: 276),
            const SizedBox(height: 52),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hesap oluştur',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: PratiCaseColors.navy,
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              height: 1.06,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'PratiCase’e katıl ve gelişimine hemen başla.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF465872),
                          fontSize: 17,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const AuthHeroIllustration(
                  type: AuthHeroType.profile,
                  size: 138,
                ),
              ],
            ),
            const SizedBox(height: 32),
            AuthTextField(
              label: 'Ad',
              hintText: 'Adınızı girin',
              controller: _firstName,
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Adını gir.' : null,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              label: 'Soyad',
              hintText: 'Soyadınızı girin',
              controller: _lastName,
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Soyadını gir.'
                  : null,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              label: 'E-posta',
              hintText: 'E-posta adresinizi girin',
              controller: _email,
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              label: 'Şifre',
              hintText: 'Şifrenizi oluşturun',
              controller: _password,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 18),
            AuthTextField(
              label: 'Şifre (Tekrar)',
              hintText: 'Şifrenizi tekrar girin',
              controller: _repeatPassword,
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: (value) {
                if (value != _password.text) return 'Şifreler eşleşmiyor.';
                return AuthValidators.password(value);
              },
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: _acceptedTerms
                          ? PratiCaseColors.teal
                          : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: PratiCaseColors.teal),
                    ),
                    child: _acceptedTerms
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF23364F),
                          height: 1.35,
                        ),
                        children: const [
                          TextSpan(text: 'Kullanım koşullarını ve '),
                          TextSpan(
                            text: 'gizlilik politikasını',
                            style: TextStyle(
                              color: PratiCaseColors.teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: ' okudum, kabul ediyorum.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            AuthPrimaryButton(
              label: 'Hesap Oluştur',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Zaten hesabın var mı?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF465872),
                  ),
                ),
                AuthLinkButton(label: 'Giriş yap', onPressed: widget.onLogin),
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
