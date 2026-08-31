import 'package:go_router/go_router.dart';

import '../../features/dev/component_gallery_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ComponentGalleryScreen(),
    ),
  ],
);
