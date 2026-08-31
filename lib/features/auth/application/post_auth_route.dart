import '../domain/auth_models.dart';

/// Where an authenticated user belongs — one place both Splash and the
/// auth screens defer to, so the decision never drifts between them.
String postAuthRoute(AuthUser user) {
  return user.profileCompleted ? '/home' : '/profile-setup';
}
