import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/conversation_tile.dart';
import '../../chat/application/chat_controller.dart';
import '../../chat/domain/chat_models.dart';

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final isToday =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (isToday) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  final dd = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$dd.$mo';
}

class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatsAsync = ref.watch(chatListProvider);

    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                'Все още нямаш чатове. Отвори "Контакти" и започни разговор.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ConversationTile(
              initials: chat.otherUser.initials,
              name: chat.otherUser.name,
              lastMessage: chat.lastMessageBody != null
                  ? CallLogMessage.display(chat.lastMessageBody!)
                  : 'Все още няма съобщения.',
              time: chat.lastMessageAt != null
                  ? _formatTime(chat.lastMessageAt!)
                  : '',
              onTap: () => context.push(
                '/chat/${chat.id}',
                extra: chat.otherUser,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            '$error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}
