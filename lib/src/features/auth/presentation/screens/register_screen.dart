import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../../../app/praticase_legal.dart';
import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';
import '../widgets/auth_visuals.dart';
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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  bool _acceptedPrivacy = false;
  bool _acceptedTerms = false;
  bool _acceptedStudyTerms = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

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
    if (!_acceptedPrivacy || !_acceptedTerms || !_acceptedStudyTerms) {
      setState(
        () => _error =
            'Devam etmek için KVKK/Gizlilik, kullanıcı sözleşmesi ve çalışma koşulları onayları gereklidir.',
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
      topPadding: 12,
      bottomPadding: 40,
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthWordmark(width: 236),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final showHero = constraints.maxWidth >= 330;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hesap oluştur',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  color: PratiCaseColors.navy,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: PratiCaseSpacing.md),
                          Text(
                            "PratiCase'e katıl ve gelişimine hemen başla.",
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: PratiCaseColors.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (showHero) ...[
                      const SizedBox(width: 12),
                      const AuthHeroIllustration(
                        type: AuthHeroType.profile,
                        size: 112,
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                color: PratiCaseColors.white,
                borderRadius: BorderRadius.circular(PratiCaseRadius.xxl),
                boxShadow: PratiCaseShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'Ad',
                    hintText: 'Ad',
                    controller: _firstName,
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Adını gir.'
                        : null,
                  ),
                  const SizedBox(height: PratiCaseSpacing.lg),
                  AuthTextField(
                    label: 'Soyad',
                    hintText: 'Soyad',
                    controller: _lastName,
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Soyadını gir.'
                        : null,
                  ),
                  const SizedBox(height: PratiCaseSpacing.lg),
                  AuthTextField(
                    label: 'E-posta',
                    hintText: 'E-posta',
                    controller: _email,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: PratiCaseSpacing.lg),
                  AuthTextField(
                    label: 'Şifre',
                    hintText: 'Şifre',
                    controller: _password,
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.password,
                  ),
                  const SizedBox(height: PratiCaseSpacing.sm),
                  PasswordStrengthIndicator(password: _password.text),
                  const SizedBox(height: PratiCaseSpacing.lg),
                  AuthTextField(
                    label: 'Şifre (Tekrar)',
                    hintText: 'Şifre Tekrar',
                    controller: _repeatPassword,
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    validator: (value) {
                      if (value != _password.text) {
                        return 'Şifreler eşleşmiyor.';
                      }
                      return AuthValidators.password(value);
                    },
                  ),
                  const SizedBox(height: PratiCaseSpacing.xl),
                  _ConsentRow(
                    value: _acceptedPrivacy,
                    label: 'KVKK / Gizlilik metnini okudum',
                    onChanged: (value) =>
                        setState(() => _acceptedPrivacy = value),
                    onOpen: () =>
                        _openLegalUrl(PratiCaseLegal.privacyPolicyUrl),
                  ),
                  _ConsentRow(
                    value: _acceptedTerms,
                    label: 'Kullanıcı sözleşmesini kabul ediyorum',
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value),
                    onOpen: () => _openLegalUrl(PratiCaseLegal.termsUrl),
                  ),
                  _ConsentRow(
                    value: _acceptedStudyTerms,
                    label: 'Çalışma koşullarını kabul ediyorum',
                    onChanged: (value) =>
                        setState(() => _acceptedStudyTerms = value),
                    onOpen: () => _openLegalUrl(PratiCaseLegal.studyTermsUrl),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(
                              top: PratiCaseSpacing.lg,
                            ),
                            child: AuthStatusCard(
                              message: _error!,
                              tone: AuthStatusTone.error,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: PratiCaseSpacing.xxl),
                  AuthPrimaryButton(
                    label: 'Hesap Oluştur',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: PratiCaseSpacing.xxl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Zaten hesabın var mı?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: PratiCaseColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AuthLinkButton(
                        label: 'Giriş yap',
                        onPressed: widget.onLogin,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLegalUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onOpen,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(PratiCaseRadius.sm),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? PratiCaseColors.teal : PratiCaseColors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: value
                          ? PratiCaseColors.teal
                          : PratiCaseColors.border,
                      width: 1.6,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          Icons.check_rounded,
                          color: PratiCaseColors.white,
                          size: 16,
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: PratiCaseSpacing.sm),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(PratiCaseRadius.md),
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PratiCaseColors.slateBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: PratiCaseColors.teal,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Aç',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
