import 'package:flutter/material.dart';

import '../../../../app/theme/praticase_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_brand.dart';
import '../widgets/auth_link_button.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_card.dart';
import '../widgets/otp_input.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.repository,
    required this.email,
    required this.fullName,
    required this.onBack,
    required this.onVerified,
    super.key,
  });

  final AuthRepository repository;
  final String email;
  final String fullName;
  final VoidCallback onBack;
  final VoidCallback onVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  String _code = '';
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = '6 haneli kodu gir.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.repository.verifyEmailCode(email: widget.email, code: _code);
      widget.onVerified();
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _success = null;
    });
    try {
      await widget.repository.resendEmailVerification(widget.email);
      setState(() => _success = 'Yeni kod gönderildi.');
    } on AuthFailure catch (failure) {
      setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthBrand(),
          const SizedBox(height: 36),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.mark_email_read_rounded,
                  size: 112,
                  color: Color(0xFFC9D8DE),
                ),
                Positioned(
                  right: -6,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: PratiCaseColors.teal,
                    child: const Icon(
                      Icons.check_rounded,
                      color: PratiCaseColors.white,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          Text(
            'E-postanı doğrula',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sana gönderdiğimiz 6 haneli kodu gir.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          AuthStatusCard(
            title: 'Kod gönderilen e-posta',
            message: widget.email.isEmpty ? 'ornek@mail.com' : widget.email,
            tone: AuthStatusTone.info,
          ),
          const SizedBox(height: 18),
          OtpInput(onChanged: (value) => _code = value),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Doğrula',
            loading: _loading,
            onPressed: _verify,
          ),
          const SizedBox(height: 10),
          Center(
            child: AuthLinkButton(
              label: 'Kodu tekrar gönder',
              onPressed: _resend,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthStatusCard(message: _error!, tone: AuthStatusTone.error),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            AuthStatusCard(message: _success!, tone: AuthStatusTone.success),
          ],
        ],
      ),
    );
  }
}
