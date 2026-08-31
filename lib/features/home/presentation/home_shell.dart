import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'calls_tab.dart';
import 'chats_tab.dart';
import 'profile_tab.dart';
import 'stories_tab.dart';

/// Chats is the default landing tab. Contacts intentionally has no tab of
/// its own — starting a chat is how you reach it (the FAB below), not a
/// destination you browse on its own.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['ConnectMe', 'Истории', 'Обаждания', 'Профил'];

  static const _tabs = [ChatsTab(), StoriesTab(), CallsTab(), ProfileTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: _index == 0
            ? [
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
