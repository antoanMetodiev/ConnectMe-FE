import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../../../shared/widgets/message_input_bar.dart';
import '../../auth/application/auth_controller.dart';
import '../../calls/application/call_controller.dart';
import '../../calls/presentation/call_screen.dart';
import '../../contacts/domain/contact_models.dart';
import '../application/chat_controller.dart';
import '../domain/chat_models.dart';
import 'photo_viewer_screen.dart';
import 'voice_message_bubble.dart';

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _formatRelative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'току-що';
  if (diff.inMinutes < 60) return 'преди ${diff.inMinutes} мин';
  if (diff.inHours < 24) return 'преди ${diff.inHours} ч';
  if (diff.inDays < 7) return 'преди ${diff.inDays} дни';
  return 'на ${_formatTime(time).replaceFirst(':', 'ч')} '
      '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, required this.otherUser});

  final String chatId;
  final UserProfile otherUser;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _scrolledOnce = false;
  DateTime? _lastTypingSentAt;

  AudioRecorder? _recorder;
  bool _recording = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;

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
    _markRead();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _markRead() {
    // Best-effort — a hiccup here (e.g. offline) shouldn't disrupt the rest
    // of the chat.
    ref.read(chatRepositoryProvider).markChatRead(widget.chatId).catchError((
      _,
    ) {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _recordTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_controller.text.isEmpty) return;
    final now = DateTime.now();
    if (_lastTypingSentAt != null &&
        now.difference(_lastTypingSentAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSentAt = now;
    ref.read(chatRepositoryProvider).sendTyping(widget.chatId);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Oldest messages are at the top now, so paging further into history
    // happens when the user scrolls up toward the start of the list.
    if (position.pixels > position.minScrollExtent + 200) return;

    final current = ref.read(chatMessageLimitProvider(widget.chatId));
    final loaded = ref.read(chatMessagesProvider(widget.chatId)).value;
    // Only ask for more once we've actually filled the current page — a
    // shorter result than requested means we've reached the start of
    // history and there's nothing further back to load.
    if (loaded != null && loaded.length >= current) {
      ref.read(chatMessageLimitProvider(widget.chatId).notifier).state =
          current + chatMessagePageSize;
    }
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(chatId: widget.chatId, body: text);
      // The listener in build() also catches this once the new message
      // streams back in, but jumping right away feels more responsive.
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

  Future<void> _startRecording() async {
    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      await recorder.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Няма достъп до микрофона.')),
        );
      }
      return;
    }
    // Voice-note-appropriate settings — mono, 16kHz, 32kbps keeps a 30s
    // clip to roughly 100-150KB instead of megabytes.
    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: 'voice-message.m4a',
    );
    _recorder = recorder;
    setState(() {
      _recording = true;
      _recordElapsed = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordElapsed += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      await recorder.cancel();
      await recorder.dispose();
    }
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;

    final blobUrl = await recorder.stop();
    final duration = _recordElapsed;
    await recorder.dispose();
    if (mounted) setState(() => _recording = false);

    // Ignore accidental taps that end before anything meaningful was
    // captured.
    if (blobUrl == null || duration.inSeconds < 1) return;

    try {
      // record's web implementation hands back a blob: URL rather than
      // bytes directly — fetching it is how those get read.
      final response = await http.get(Uri.parse(blobUrl));
      await ref
          .read(chatRepositoryProvider)
          .sendVoice(
            chatId: widget.chatId,
            bytes: response.bodyBytes,
            duration: duration,
          );
      if (mounted) _scrollToBottom(animate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pickAndSendPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерия'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(chatRepositoryProvider)
          .sendPhoto(chatId: widget.chatId, bytes: bytes);
      if (mounted) _scrollToBottom(animate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _startCall({required bool video}) async {
    try {
      final call = await ref
          .read(callActionsProvider)
          .startCall(otherUserId: widget.otherUser.id, video: video);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              call: call,
              outgoingCallLog: OutgoingCallLog(
                video: video,
                writeMessage: (body) => ref
                    .read(chatRepositoryProvider)
                    .sendMessage(chatId: widget.chatId, body: body),
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
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final participants = (
      chatId: widget.chatId,
      otherUserId: widget.otherUser.id,
    );
    final isOtherTyping =
        ref.watch(chatOtherTypingProvider(participants)).value ?? false;
    final otherLastRead =
        ref.watch(chatOtherLastReadProvider(participants)).value;

    // A new message landing while this screen is open should immediately
    // count as read too, not just the initial open. Compare the newest
    // message's id (not just "did it emit") so paging in older history
    // doesn't re-trigger this on every page.
    ref.listen(chatMessagesProvider(widget.chatId), (previous, next) {
      final previousNewest = previous?.value?.isNotEmpty ?? false
          ? previous!.value!.first.id
          : null;
      final nextNewest = next.value?.isNotEmpty ?? false
          ? next.value!.first.id
          : null;
      if (nextNewest != null && nextNewest != previousNewest) {
        _markRead();
        _scrollToBottom(animate: _scrolledOnce);
        _scrolledOnce = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AppAvatar(
              initials: widget.otherUser.initials,
              imageUrl: widget.otherUser.avatarUrl,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.otherUser.name, overflow: TextOverflow.ellipsis),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: isOtherTyping
                        ? Text(
                            'Пише…',
                            key: const ValueKey('typing'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : const SizedBox(height: 0, key: ValueKey('idle')),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _startCall(video: false),
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Аудио разговор',
          ),
          IconButton(
            onPressed: () => _startCall(video: true),
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
                      'Кажи "здравей" 👋',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                // The provider yields newest-first (handy for pagination);
                // flip it here so the list reads top-to-bottom like every
                // other chat app, oldest at the top.
                final ascending = messages.reversed.toList();
                final newestIsMineAndRead =
                    messages.first.senderId == myId &&
                    otherLastRead != null &&
                    !otherLastRead.isBefore(messages.first.createdAt);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: ascending.length,
                  itemBuilder: (context, index) {
                    final message = ascending[index];
                    // Consecutive messages from the same person sit close
                    // together; a change of sender (or a call-log breaking
                    // the run) gets visibly more breathing room above it.
                    final previous = index > 0 ? ascending[index - 1] : null;
                    final isSenderChange =
                        previous == null ||
                        CallLogMessage.isCallLog(previous.body) ||
                        previous.senderId != message.senderId;
                    final topSpacing = isSenderChange
                        ? AppSpacing.lg
                        : AppSpacing.xs;
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
                                startedByMe: message.senderId == myId,
                                otherName: widget.otherUser.name,
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
                    if (PhotoMessage.isPhoto(message.body)) {
                      final isMine = message.senderId == myId;
                      final viewed = PhotoMessage.isViewed(message.body);
                      final storagePath = PhotoMessage.storagePath(
                        message.body,
                      );
                      return Padding(
                        padding: EdgeInsets.only(
                          top: topSpacing,
                          bottom: AppSpacing.xs,
                        ),
                        child: _PhotoBubble(
                          isMine: isMine,
                          viewed: viewed,
                          // Only the recipient can open it — the sender
                          // never gets a second look either.
                          canOpen: !isMine && storagePath != null,
                          onTap: storagePath == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PhotoViewerScreen(
                                      messageId: message.id,
                                      storagePath: storagePath,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    }
                    if (VoiceMessage.isVoice(message.body)) {
                      final storagePath = VoiceMessage.storagePath(
                        message.body,
                      );
                      if (storagePath != null) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: topSpacing,
                            bottom: AppSpacing.xs,
                          ),
                          child: VoiceMessageBubble(
                            isMine: message.senderId == myId,
                            storagePath: storagePath,
                            duration: VoiceMessage.duration(message.body),
                          ),
                        );
                      }
                    }
                    final storyReplyText = StoryReplyMessage.display(
                      message.body,
                      startedByMe: message.senderId == myId,
                      otherName: widget.otherUser.name,
                    );
                    final bubble = MessageBubble(
                      text: storyReplyText ?? message.body,
                      time: _formatTime(message.createdAt),
                      isMine: message.senderId == myId,
                    );
                    final isNewest = index == ascending.length - 1;
                    if (isNewest && newestIsMineAndRead) {
                      return Padding(
                        padding: EdgeInsets.only(
                          top: topSpacing,
                          bottom: AppSpacing.xs,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bubble,
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 2,
                                right: 2,
                              ),
                              child: Text(
                                'Видяно, ${_formatRelative(otherLastRead)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
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
          if (_recording)
            _RecordingBar(
              elapsed: _recordElapsed,
              onCancel: _cancelRecording,
              onStop: _stopRecordingAndSend,
            )
          else
            MessageInputBar(
              controller: _controller,
              onSend: _send,
              onAttach: _pickAndSendPhoto,
              onRecord: _startRecording,
            ),
        ],
      ),
    );
  }
}

/// A view-once photo message. Tapping it (when [canOpen]) is what actually
/// downloads and consumes it — this widget never shows the image itself.
class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({
    required this.isMine,
    required this.viewed,
    required this.canOpen,
    this.onTap,
  });

  final bool isMine;
  final bool viewed;
  final bool canOpen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = canOpen && !viewed;
    final label = viewed
        ? 'Снимката е отворена'
        : (canOpen ? 'Снимка — докосни, за да отвориш' : 'Изпратена снимка');
    final foreground = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Material(
        color: isMine
            ? theme.colorScheme.primary.withValues(alpha: viewed ? 0.5 : 1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  viewed ? Icons.image_outlined : Icons.camera_alt,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces [MessageInputBar] while a voice message is being recorded.
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.elapsed,
    required this.onCancel,
    required this.onStop,
  });

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Отказ',
            ),
            Icon(
              Icons.fiber_manual_record,
              color: theme.colorScheme.error,
              size: 14,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text('$mm:$ss', style: theme.textTheme.bodyMedium),
            const Spacer(),
            IconButton(
              onPressed: onStop,
              icon: const Icon(Icons.send_rounded),
              color: theme.colorScheme.primary,
              tooltip: 'Изпрати',
            ),
          ],
        ),
      ),
    );
  }
}
