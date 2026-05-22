class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.emailVerified = false,
    this.profileCompleted = false,
  });

  final String id;
  final String email;
  final String? fullName;
  final bool emailVerified;
  final bool profileCompleted;
}
