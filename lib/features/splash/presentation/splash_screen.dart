import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/post_auth_route.dart';
import '../../onboarding/data/onboarding_prefs.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    if (!Env.isSupabaseConfigured) {
      context.go('/login');
      return;
    }

    final user = ref.read(authControllerProvider).value;
    if (user != null) {
      context.go(postAuthRoute(user));
      return;
    }

    final seenOnboarding = await OnboardingPrefs.hasSeenOnboarding();
    if (!mounted) return;
    context.go(seenOnboarding ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
