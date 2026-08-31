import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/config/env.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(supabase.Supabase.instance.client);
});

class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  FutureOr<AuthUser?> build() {
    if (!Env.isSupabaseConfigured) return null;

    final repository = ref.watch(authRepositoryProvider);
    // Keeps state in sync with sign-in/out from anywhere — crucially, this
    // is what picks up the session after a Google OAuth redirect reloads
    // the app, since that flow never "returns" a user the way email/password
    // sign-in does.
    final subscription = repository.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    ref.onDispose(subscription.cancel);

    return repository.currentUser;
  }

  Future<void> signIn({required String email, required String password}) {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _run(
      () => ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            displayName: displayName,
          ),
    );
  }

  Future<void> completeProfileSetup({required String displayName}) {
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .completeProfileSetup(displayName: displayName),
    );
  }

  Future<void> signInWithGoogle() async {
    if (!Env.isSupabaseConfigured) {
      state = AsyncError(
        const AuthFailure(
          'Supabase не е конфигуриран още — виж env.example.json.',
        ),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // No return value on success — the tab is about to navigate away to
      // Google. Whatever happens next arrives through authStateChanges().
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }

  Future<void> signOut() async {
    if (!Env.isSupabaseConfigured) return;
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  Future<void> _run(Future<AuthUser> Function() action) async {
    if (!Env.isSupabaseConfigured) {
      state = AsyncError(
        const AuthFailure(
          'Supabase не е конфигуриран още — виж env.example.json.',
        ),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
