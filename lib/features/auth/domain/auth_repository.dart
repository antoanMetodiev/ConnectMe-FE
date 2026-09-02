import 'dart:typed_data';

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

  /// Updates the caller's own name and/or avatar. Pass only what changed —
  /// omitted fields are left as they are.
  Future<AuthUser> updateProfile({String? displayName, String? avatarUrl});

  /// Uploads a new avatar image and returns its public URL. Doesn't update
  /// the profile itself — pass the result to [updateProfile].
  Future<String> uploadAvatar(Uint8List bytes);

  Future<void> signOut();
}
