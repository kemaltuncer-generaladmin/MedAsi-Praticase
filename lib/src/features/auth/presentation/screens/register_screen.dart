import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../../../app/theme/praticase_tokens.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_validators.dart';

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
  static const _universities = [
    'Hacettepe Üniversitesi',
    'İstanbul Üniversitesi',
    'Ankara Üniversitesi',
    'Ege Üniversitesi',
    'Gazi Üniversitesi',
    'Marmara Üniversitesi',
    'Dokuz Eylül Üniversitesi',
    'Uludağ Üniversitesi',
    'Diğer',
  ];

  static const _faculties = [
    'Tıp Fakültesi',
    'Diş Hekimliği Fakültesi',
    'Eczacılık Fakültesi',
    'Hemşirelik Fakültesi',
    'Sağlık Bilimleri Fakültesi',
    'Diğer',
  ];

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _university;
  String? _faculty;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      onBack: widget.onBack,
      child: AuthCard(
        children: [
          const AuthScreenHeader(
            title: 'Aramıza Katılın ✨',
            subtitle: 'Tek hesap, üç güçlü uygulama',
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
                  label: 'Ad',
                  hintText: 'Ad',
                  controller: _firstName,
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
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
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Soyadını gir.'
                      : null,
                ),
                const SizedBox(height: PratiCaseSpacing.lg),
                _AuthSelectField(
                  label: 'Üniversite',
                  hintText: 'Üniversitenizi seçin',
                  value: _university,
                  items: _universities,
                  icon: Icons.school_outlined,
                  onChanged: (value) => setState(() => _university = value),
                ),
                const SizedBox(height: PratiCaseSpacing.lg),
                _AuthSelectField(
                  label: 'Fakülte',
                  hintText: 'Fakültenizi seçin',
                  value: _faculty,
                  items: _faculties,
                  icon: Icons.account_balance_outlined,
                  onChanged: (value) => setState(() => _faculty = value),
                ),
                const SizedBox(height: PratiCaseSpacing.lg),
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
                  identifier: 'cta.register-submit',
                  label: 'Hesabımı Oluştur',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Zaten hesabın var mı? ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PratiCaseColors.slateBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AuthLinkButton(label: 'Giriş Yap', onPressed: widget.onLogin),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthSelectField extends StatelessWidget {
  const _AuthSelectField({
    required this.label,
    required this.hintText,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String hintText;
  final String? value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3E5E86),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF7FAAD4),
          ),
          validator: (selected) => selected == null ? '$label seç.' : null,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: const Color(0xFF7FAAD4), size: 21),
            filled: true,
            fillColor: const Color(0xFFF7FBFF),
            hintStyle: const TextStyle(
              color: Color(0xFF8A99AA),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC7DCF3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC7DCF3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF1D67D2),
                width: 1.4,
              ),
            ),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PratiCaseColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
