import 'auth_models.dart';

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> signIn({
    required String email,
    required String password,
  });

  /// Kicks off the Google OAuth redirect. On web this navigates the tab away
  /// and back — the resulting session shows up through [authStateChanges],
  /// not as a return value here.
  Future<void> signInWithGoogle();

  Future<AuthUser> completeProfileSetup({required String displayName});

  Future<void> signOut();
}
