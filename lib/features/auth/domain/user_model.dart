class AuthUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  @override
  String toString() => 'AuthUser(id: $id, email: $email, name: $displayName)';
}
