import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/contacts/domain/contact_models.dart';
import '../../features/contacts/presentation/contact_activity_screen.dart';
import '../../features/contacts/presentation/incoming_requests_screen.dart';
import '../../features/contacts/presentation/search_users_screen.dart';
import '../../features/dev/component_gallery_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
    GoRoute(
      path: '/contacts/search',
      builder: (context, state) => const SearchUsersScreen(),
    ),
    GoRoute(
      path: '/contacts/requests',
      builder: (context, state) => const IncomingRequestsScreen(),
    ),
    GoRoute(
      path: '/contacts/activity',
      builder: (context, state) => const ContactActivityScreen(),
    ),
    GoRoute(
      path: '/chat/:chatId',
      builder: (context, state) => ChatScreen(
        chatId: state.pathParameters['chatId']!,
        otherUser: state.extra as UserProfile,
      ),
    ),
    GoRoute(
      path: '/dev/components',
      builder: (context, state) => const ComponentGalleryScreen(),
    ),
  ],
);
