class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
    this.profileCompleted = false,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool profileCompleted;
}

/// User-facing auth error, decoupled from whichever backend raised it.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
