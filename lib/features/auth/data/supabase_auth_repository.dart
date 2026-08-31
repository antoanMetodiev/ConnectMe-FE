import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((state) {
      return _toAuthUser(state.session?.user);
    });
  }

  @override
  AuthUser? get currentUser => _toAuthUser(_client.auth.currentUser);

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure(
          'Регистрацията стартира — провери имейла си, за да я потвърдиш.',
        );
      }
      return _toAuthUser(user)!;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Неуспешен вход. Опитай пак.');
      }
      return _toAuthUser(user)!;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      // `redirectTo` must also be listed under Supabase → Authentication →
      // URL Configuration → Redirect URLs, or the provider rejects it.
      // Mobile builds will need a custom URL scheme here instead once we
      // target Android/iOS — web-only for now.
      await _client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
    } on supabase.AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthUser? _toAuthUser(supabase.User? user) {
    if (user == null || user.email == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email!,
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }

  String _friendlyMessage(supabase.AuthException e) {
    switch (e.message.toLowerCase()) {
      case 'invalid login credentials':
        return 'Грешен имейл или парола.';
      case 'user already registered':
        return 'Вече има акаунт с този имейл.';
      default:
        return e.message;
    }
  }
}
