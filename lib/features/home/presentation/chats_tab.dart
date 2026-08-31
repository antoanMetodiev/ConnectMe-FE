import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/conversation_tile.dart';

class _Conversation {
  const _Conversation({
    required this.initials,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.presence = PresenceStatus.offline,
    this.unreadCount = 0,
  });

  final String initials;
  final String name;
  final String lastMessage;
  final String time;
  final PresenceStatus presence;
  final int unreadCount;
}

// Placeholder data — replaced once conversations come from Supabase.
const _conversations = [
  _Conversation(
    initials: 'М',
    name: 'Мария',
    lastMessage: 'Готино, чакам те!',
    time: '14:03',
    presence: PresenceStatus.online,
    unreadCount: 2,
  ),
  _Conversation(
    initials: 'И',
    name: 'Иван',
    lastMessage: 'Пращам ти утре сутринта',
    time: '12:47',
  ),
  _Conversation(
    initials: 'Г',
    name: 'Familia',
    lastMessage: 'Тати: Стигнахме добре',
    time: 'вчера',
    unreadCount: 5,
  ),
  _Conversation(
    initials: 'Е',
    name: 'Елена',
    lastMessage: 'Виж снимката 📷',
    time: 'вчера',
    presence: PresenceStatus.online,
  ),
  _Conversation(
    initials: 'Н',
    name: 'Никола',
    lastMessage: 'Благодаря!',
    time: 'понеделник',
  ),
];

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _conversations[index];
        return ConversationTile(
          initials: c.initials,
          name: c.name,
          lastMessage: c.lastMessage,
          time: c.time,
          presence: c.presence,
          unreadCount: c.unreadCount,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Отваряне на чат — скоро.')),
          ),
        );
      },
    );
  }
}
