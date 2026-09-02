import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../../../shared/widgets/message_input_bar.dart';
import '../../auth/application/auth_controller.dart';
import '../../calls/application/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../chat/domain/chat_models.dart';
import '../application/groups_controller.dart';

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _scrolledOnce = false;

  void _scrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.minScrollExtent + 200) return;

    final current = ref.read(groupMessageLimitProvider(widget.groupId));
    final loaded = ref.read(groupMessagesProvider(widget.groupId)).value;
    if (loaded != null && loaded.length >= current) {
      ref.read(groupMessageLimitProvider(widget.groupId).notifier).state =
          current + groupMessagePageSize;
    }
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref
          .read(groupsRepositoryProvider)
          .sendGroupMessage(groupId: widget.groupId, body: text);
      _scrollToBottom(animate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startCall({
    required bool video,
    required List<String> otherMemberIds,
  }) async {
    try {
      final call = await ref
          .read(callActionsProvider)
          .startGroupCall(memberIds: otherMemberIds, video: video);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              call: call,
              outgoingCallLog: OutgoingCallLog(
                video: video,
                writeMessage: (body) => ref
                    .read(groupsRepositoryProvider)
                    .sendGroupMessage(groupId: widget.groupId, body: body),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = ref.watch(authControllerProvider).value?.id;
    final groupAsync = ref.watch(groupProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final messagesAsync = ref.watch(groupMessagesProvider(widget.groupId));

    final membersById = {
      for (final m in membersAsync.value ?? const [])
        m.id: m,
    };

    ref.listen(groupMessagesProvider(widget.groupId), (previous, next) {
      final previousNewest = previous?.value?.isNotEmpty ?? false
          ? previous!.value!.first.id
          : null;
      final nextNewest = next.value?.isNotEmpty ?? false
          ? next.value!.first.id
          : null;
      if (nextNewest != null && nextNewest != previousNewest) {
        _scrollToBottom(animate: _scrolledOnce);
        _scrolledOnce = true;
      }
    });

    final otherMemberIds = (groupAsync.value?.memberIds ?? const [])
        .where((id) => id != myId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              groupAsync.value?.name ?? '…',
              overflow: TextOverflow.ellipsis,
            ),
            if (groupAsync.value != null)
              Text(
                '${groupAsync.value!.memberIds.length} членове',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: otherMemberIds.isEmpty
                ? null
                : () => _startCall(video: false, otherMemberIds: otherMemberIds),
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Аудио разговор',
          ),
          IconButton(
            onPressed: otherMemberIds.isEmpty
                ? null
                : () => _startCall(video: true, otherMemberIds: otherMemberIds),
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Видео разговор',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Кажи "здравей" на групата 👋',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final ascending = messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: ascending.length,
                  itemBuilder: (context, index) {
                    final message = ascending[index];
                    final previous = index > 0 ? ascending[index - 1] : null;
                    final isSenderChange =
                        previous == null ||
                        CallLogMessage.isCallLog(previous.body) ||
                        previous.senderId != message.senderId;
                    final topSpacing = isSenderChange
                        ? AppSpacing.lg
                        : AppSpacing.xs;
                    final senderName =
                        membersById[message.senderId]?.name ?? '…';
                    final isMine = message.senderId == myId;

                    if (CallLogMessage.isCallLog(message.body)) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${CallLogMessage.display(
                                message.body,
                                startedByMe: isMine,
                                otherName: senderName,
                              )} · '
                              '${_formatTime(message.createdAt)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final bubble = Column(
                      crossAxisAlignment: isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isMine)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.sm,
                              bottom: 2,
                            ),
                            child: Text(
                              senderName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        MessageBubble(
                          text: message.body,
                          time: _formatTime(message.createdAt),
                          isMine: isMine,
                        ),
                      ],
                    );

                    return Padding(
                      padding: EdgeInsets.only(
                        top: topSpacing,
                        bottom: AppSpacing.xs,
                      ),
                      child: bubble,
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
            ),
          ),
          MessageInputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}
