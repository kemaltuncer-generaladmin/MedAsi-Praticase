import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/verify_email_screen.dart';

enum AuthStep {
  onboarding,
  login,
  register,
  verifyEmail,
  forgotPassword,
  resetPassword,
  profileSetup,
}

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    required this.authRepository,
    required this.onAuthenticated,
    this.initialStep = AuthStep.onboarding,
    this.initialEmail = '',
    this.initialFullName = '',
    super.key,
  });

  final AuthRepository authRepository;
  final VoidCallback onAuthenticated;
  final AuthStep initialStep;
  final String initialEmail;
  final String initialFullName;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  late AuthStep _step;
  late String _email;
  late String _fullName;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _email = widget.initialEmail;
    _fullName = widget.initialFullName;
  }

  void _go(AuthStep step) => setState(() => _step = step);

  void _setEmail(String email) => _email = email;

  void _setFullName(String fullName) => _fullName = fullName;

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      AuthStep.onboarding => OnboardingScreen(
        onCreateAccount: () => _go(AuthStep.register),
        onLogin: () => _go(AuthStep.login),
      ),
      AuthStep.login => LoginScreen(
        repository: widget.authRepository,
        onBack: () => _go(AuthStep.onboarding),
        onForgotPassword: () => _go(AuthStep.forgotPassword),
        onRegister: () => _go(AuthStep.register),
        onSignedIn: (user) {
          _setEmail(user.email);
          _setFullName(user.fullName ?? '');
          if (user.profileCompleted) {
            widget.onAuthenticated();
          } else {
            _go(AuthStep.profileSetup);
          }
        },
      ),
      AuthStep.register => RegisterScreen(
        repository: widget.authRepository,
        onBack: () => _go(AuthStep.onboarding),
        onLogin: () => _go(AuthStep.login),
        onRegistered: (email, fullName) {
          _setEmail(email);
          _setFullName(fullName);
          _go(AuthStep.verifyEmail);
        },
      ),
      AuthStep.verifyEmail => VerifyEmailScreen(
        repository: widget.authRepository,
        email: _email,
        fullName: _fullName,
        onBack: () => _go(AuthStep.register),
        onVerified: () => _go(AuthStep.profileSetup),
      ),
      AuthStep.forgotPassword => ForgotPasswordScreen(
        repository: widget.authRepository,
        onBack: () => _go(AuthStep.login),
        onCodeSent: (email) {
          _setEmail(email);
          _go(AuthStep.resetPassword);
        },
      ),
      AuthStep.resetPassword => ResetPasswordScreen(
        repository: widget.authRepository,
        email: _email,
        onBack: () => _go(AuthStep.forgotPassword),
        onPasswordUpdated: () => _go(AuthStep.login),
      ),
      AuthStep.profileSetup => ProfileSetupScreen(
        repository: widget.authRepository,
        fullName: _fullName,
        onBack: () => _go(
          widget.initialStep == AuthStep.profileSetup
              ? AuthStep.login
              : AuthStep.verifyEmail,
        ),
        onCompleted: widget.onAuthenticated,
      ),
    };
  }
}
