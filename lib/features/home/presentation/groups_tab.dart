import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/conversation_tile.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/domain/chat_models.dart';
import '../../groups/application/groups_controller.dart';

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

String _previewText(String body, {required bool startedByMe}) {
  if (PhotoMessage.isPhoto(body)) {
    return PhotoMessage.isViewed(body) ? '📷 Снимка (отворена)' : '📷 Снимка';
  }
  if (VoiceMessage.isVoice(body)) {
    final total = VoiceMessage.duration(body).inSeconds;
    final mm = total ~/ 60;
    final ss = (total % 60).toString().padLeft(2, '0');
    return '🎤 Гласово съобщение · $mm:$ss';
  }
  return CallLogMessage.display(
    body,
    startedByMe: startedByMe,
    otherName: 'Някой',
  );
}

class GroupsTab extends ConsumerWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(groupListProvider);
    final myId = ref.watch(authControllerProvider).value?.id;

    if (groupsAsync.hasError) {
      return _ErrorState(error: groupsAsync.error!);
    }
    if (!groupsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = groupsAsync.value!;

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'Все още нямаш групи. Натисни бутона горе, за да създадеш нова.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final group = groups[index];
        return ConversationTile(
          initials: group.initials,
          name: group.name,
          lastMessage: group.lastMessageBody != null
              ? _previewText(
                  group.lastMessageBody!,
                  startedByMe: group.lastMessageSenderId == myId,
                )
              : '${group.memberIds.length} членове',
          time: group.lastMessageAt != null
              ? _formatTime(group.lastMessageAt!)
              : '',
          onTap: () => context.push('/group/${group.id}'),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
    );
  }
}
