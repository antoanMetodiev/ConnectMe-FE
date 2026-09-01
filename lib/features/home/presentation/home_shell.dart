import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../calls/application/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../contacts/application/contacts_controller.dart';
import 'calls_tab.dart';
import 'chats_tab.dart';
import 'contacts_tab.dart';
import 'profile_tab.dart';
import 'stories_tab.dart';

/// Chats is the default landing tab.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  String? _handledIncomingCallId;

  static const _titles = [
    'ConnectMe',
    'Контакти',
    'Истории',
    'Обаждания',
    'Профил',
  ];

  static const _tabs = [
    ChatsTab(),
    ContactsTab(),
    StoriesTab(),
    CallsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingRequestsCountProvider).value ?? 0;
    final unseenActivityCount =
        ref.watch(unseenContactActivityCountProvider).value ?? 0;

    // Foreground-only: catches a ring while the app is open, on any tab,
    // and opens the call screen — Stream's own UI handles accept/decline.
    ref.listen(incomingCallProvider, (previous, next) {
      final call = next.value;
      if (call == null || call.id == _handledIncomingCallId) return;
      _handledIncomingCallId = call.id;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => CallScreen(call: call)));
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: _index == 0
            ? [
                IconButton(
                  onPressed: () => context.push('/contacts/activity'),
                  icon: Badge.count(
                    count: unseenActivityCount,
                    isLabelVisible: unseenActivityCount > 0,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'Известия',
                ),
                IconButton(
                  onPressed: () => context.push('/contacts/requests'),
                  icon: Badge.count(
                    count: pendingCount,
                    isLabelVisible: pendingCount > 0,
                    child: const Icon(Icons.person_add_alt_1_outlined),
                  ),
                  tooltip: 'Входящи покани',
                ),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Търсене — скоро.')),
                  ),
                  icon: const Icon(Icons.search),
                ),
              ]
            : null,
      ),
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: () => context.push('/contacts/search'),
              child: const Icon(Icons.add_comment_outlined),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Чатове',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Контакти',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Истории',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Обаждания',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профил',
          ),
        ],
      ),
    );
  }
}
