import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

const _avatarsBucket = 'avatars';

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
      // No session yet means email confirmation is pending — there's no
      // authenticated user to hand back until they confirm and sign in.
      if (response.user == null || response.session == null) {
        throw const AuthFailure(
          'Регистрацията стартира — провери имейла си, за да я потвърдиш, '
          'после влез.',
        );
      }
      return _toAuthUser(response.user)!;
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
  Future<AuthUser> completeProfileSetup({required String displayName}) async {
    try {
      final response = await _client.auth.updateUser(
        supabase.UserAttributes(
          data: {'display_name': displayName, 'profile_completed': true},
        ),
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Неуспешно запазване. Опитай пак.');
      }
      return _toAuthUser(user)!;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    }
  }

  @override
  Future<AuthUser> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final response = await _client.auth.updateUser(
        supabase.UserAttributes(
          data: {
            'display_name': ?displayName,
            'avatar_url': ?avatarUrl,
          },
        ),
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Неуспешно запазване. Опитай пак.');
      }
      return _toAuthUser(user)!;
    } on supabase.AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    }
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure('Трябва да си влязъл, за да смениш снимката.');
    }
    final path = '$userId/avatar.jpg';
    try {
      // Remove-then-insert rather than upsert: true — simpler to reason
      // about under RLS, and a missing prior file is a harmless no-op.
      try {
        await _client.storage.from(_avatarsBucket).remove([path]);
      } catch (_) {
        // Nothing to remove on the first-ever upload — fine.
      }
      await _client.storage
          .from(_avatarsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const supabase.FileOptions(
              contentType: 'image/jpeg',
            ),
          );
      // Cache-bust — the path never changes, so without this the browser
      // (and any CDN in front of Storage) would keep showing the old image.
      final publicUrl = _client.storage.from(_avatarsBucket).getPublicUrl(path);
      return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } on supabase.StorageException catch (e) {
      throw AuthFailure(e.message);
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
      avatarUrl:
          (user.userMetadata?['avatar_url'] ??
                  user.userMetadata?['picture'])
              as String?,
      createdAt: DateTime.tryParse(user.createdAt),
      profileCompleted: user.userMetadata?['profile_completed'] == true,
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
