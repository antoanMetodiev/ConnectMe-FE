import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/chat_controller.dart';
import '../../chat/domain/chat_models.dart';
import '../application/stories_controller.dart';
import '../domain/story_models.dart';

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'току-що';
  if (diff.inMinutes < 60) return 'преди ${diff.inMinutes} мин';
  return 'преди ${diff.inHours} ч';
}

String _viewersLabel(int count) {
  if (count == 0) return 'Все още никой не е видял';
  return count == 1 ? '1 видя историята' : '$count видяха историята';
}

class _FlatEntry {
  const _FlatEntry({
    required this.story,
    required this.group,
    required this.indexInGroup,
  });

  final Story story;
  final StoryGroup group;
  final int indexInGroup;
}

List<_FlatEntry> _flatten(List<StoryGroup> groups) {
  final flat = <_FlatEntry>[];
  for (final group in groups) {
    for (var i = 0; i < group.stories.length; i++) {
      flat.add(
        _FlatEntry(story: group.stories[i], group: group, indexInGroup: i),
      );
    }
  }
  return flat;
}

int _startFlatIndexFor(List<StoryGroup> groups, int startGroupIndex) {
  var index = 0;
  for (var i = 0; i < startGroupIndex && i < groups.length; i++) {
    index += groups[i].stories.length;
  }
  return index;
}

/// Full-screen story viewer — pages through every story from every passed
/// group as one flat sequence, so swiping past the last story of an author
/// naturally lands on the next author's first one, same as every other
/// stories UI.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.startIndex,
  });

  final List<StoryGroup> groups;
  final int startIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with TickerProviderStateMixin {
  static const _imageDuration = Duration(seconds: 6);

  late final List<_FlatEntry> _flat;
  late final PageController _pageController;
  late final AnimationController _progress;
  late final AnimationController _heartPop;
  late final Animation<double> _heartScale;
  late int _currentIndex;

  VideoPlayerController? _videoController;
  String? _currentMediaUrl;
  bool _loadError = false;
  bool _paused = false;

  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  bool _replyFocused = false;

  _FlatEntry get _entry => _flat[_currentIndex];

  @override
  void initState() {
    super.initState();
    _flat = _flatten(widget.groups);
    _progress = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goNext();
      });
    _heartPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_heartPop);
    _replyController.addListener(() => setState(() {}));
    _replyFocusNode.addListener(() {
      _setPaused(_replyFocusNode.hasFocus);
      setState(() => _replyFocused = _replyFocusNode.hasFocus);
    });

    if (_flat.isEmpty) {
      _currentIndex = 0;
      _pageController = PageController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }

    _currentIndex = _startFlatIndexFor(
      widget.groups,
      widget.startIndex,
    ).clamp(0, _flat.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadCurrent();
  }

  @override
  void dispose() {
    _progress.dispose();
    _heartPop.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    _progress.stop();
    _progress.value = 0;
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _currentMediaUrl = null;
      _loadError = false;
    });

    final entry = _entry;
    final myId = ref.read(authControllerProvider).value?.id;
    if (entry.story.userId != myId) {
      // Fire-and-forget — never block viewing on this.
      ref.read(storiesRepositoryProvider).markViewed(entry.story.id);
    }

    try {
      final url = await ref
          .read(storiesRepositoryProvider)
          .mediaUrl(entry.story.mediaPath);
      // The user may have swiped again while this was in flight.
      if (!mounted || !identical(entry, _entry)) return;

      if (entry.story.mediaType == StoryMediaType.video) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
        if (!mounted || !identical(entry, _entry)) {
          controller.dispose();
          return;
        }
        _videoController = controller;
        _progress.duration = controller.value.duration;
        controller.play();
      } else {
        _progress.duration = _imageDuration;
      }
      setState(() => _currentMediaUrl = url);
      if (!_paused) _progress.forward(from: 0);
    } catch (_) {
      if (mounted && identical(entry, _entry)) {
        setState(() => _loadError = true);
      }
    }
  }

  void _close() {
    ref.invalidate(storyGroupsProvider);
    Navigator.of(context).maybePop();
  }

  void _goNext() {
    if (_currentIndex >= _flat.length - 1) {
      _close();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goPrevious() {
    if (_currentIndex == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _loadCurrent();
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (paused) {
      _progress.stop();
      _videoController?.pause();
    } else {
      _progress.forward();
      _videoController?.play();
    }
  }

  Future<void> _toggleLike() async {
    final entry = _entry;
    final newLiked = !entry.story.likedByMe;
    if (newLiked) _heartPop.forward(from: 0);
    final updated = Story(
      id: entry.story.id,
      userId: entry.story.userId,
      mediaPath: entry.story.mediaPath,
      mediaType: entry.story.mediaType,
      createdAt: entry.story.createdAt,
      expiresAt: entry.story.expiresAt,
      likeCount: entry.story.likeCount + (newLiked ? 1 : -1),
      likedByMe: newLiked,
      viewCount: entry.story.viewCount,
      viewedByMe: entry.story.viewedByMe,
    );
    setState(() {
      _flat[_currentIndex] = _FlatEntry(
        story: updated,
        group: entry.group,
        indexInGroup: entry.indexInGroup,
      );
    });
    try {
      await ref
          .read(storiesRepositoryProvider)
          .setLiked(storyId: entry.story.id, liked: newLiked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _flat[_currentIndex] = entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final entry = _entry;
    _replyController.clear();
    _replyFocusNode.unfocus();
    try {
      final chatId = await ref
          .read(chatRepositoryProvider)
          .findOrCreateChat(entry.story.userId);
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chatId: chatId,
            body: StoryReplyMessage.encode(
              storyId: entry.story.id,
              text: text,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Отговорът до ${entry.group.author.name} е изпратен.'),
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

  Future<void> _openViewers() async {
    _setPaused(true);
    final entry = _entry;
    List<StoryViewer>? viewers;
    try {
      viewers = await ref
          .read(storiesRepositoryProvider)
          .viewers(entry.story.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ViewersSheet(viewers: viewers ?? const []),
    );
    if (mounted) _setPaused(false);
  }

  Future<void> _deleteStory() async {
    _setPaused(true);
    final entry = _entry;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изтриване на историята'),
        content: const Text(
          'Сигурен ли си, че искаш да изтриеш тази история?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отказ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Изтрий'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (mounted) _setPaused(false);
      return;
    }
    try {
      await ref
          .read(storiesRepositoryProvider)
          .deleteStory(storyId: entry.story.id, mediaPath: entry.story.mediaPath);
      if (mounted) _close();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
        _setPaused(false);
      }
    }
  }

  Widget _buildMedia(_FlatEntry entry) {
    if (_loadError) {
      return const Center(
        child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
      );
    }
    if (entry.story.mediaType == StoryMediaType.video) {
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }
    final url = _currentMediaUrl;
    if (url == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: Image.network(url, fit: BoxFit.contain, width: double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_flat.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final myId = ref.watch(authControllerProvider).value?.id;
    final entry = _entry;
    final isMine = entry.story.userId == myId;
    final hasReplyText = _replyController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _flat.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final width = MediaQuery.sizeOf(context).width;
                    if (details.localPosition.dx < width / 3) {
                      _goPrevious();
                    } else {
                      _goNext();
                    }
                  },
                  onLongPressStart: (_) => _setPaused(true),
                  onLongPressEnd: (_) => _setPaused(false),
                  child: index == _currentIndex
                      ? _buildMedia(_flat[index])
                      : const ColoredBox(color: Colors.black),
                );
              },
            ),
            _TopBar(
              entry: entry,
              progress: _progress,
              isMine: isMine,
              onDelete: _deleteStory,
              onClose: _close,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: isMine
                            ? _ViewCountBar(
                                viewCount: entry.story.viewCount,
                                onTap: _openViewers,
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: _replyFocused ? 0.22 : 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          26,
                                        ),
                                        border: Border.all(
                                          color: _replyFocused
                                              ? Colors.white70
                                              : Colors.white24,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _replyController,
                                              focusNode: _replyFocusNode,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                              cursorColor: Colors.white,
                                              textInputAction:
                                                  TextInputAction.send,
                                              onSubmitted: (_) => _sendReply(),
                                              decoration: const InputDecoration(
                                                hintText: 'Отговори…',
                                                hintStyle: TextStyle(
                                                  color: Colors.white60,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 12,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            transitionBuilder: (child, anim) =>
                                                ScaleTransition(
                                                  scale: anim,
                                                  child: FadeTransition(
                                                    opacity: anim,
                                                    child: child,
                                                  ),
                                                ),
                                            child: hasReplyText
                                                ? Padding(
                                                    key: const ValueKey(
                                                      'send',
                                                    ),
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4,
                                                        ),
                                                    child: Material(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      shape:
                                                          const CircleBorder(),
                                                      child: InkWell(
                                                        customBorder:
                                                            const CircleBorder(),
                                                        onTap: _sendReply,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .arrow_upward_rounded,
                                                            size: 18,
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.onPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox(
                                                    key: ValueKey('empty'),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  ScaleTransition(
                                    scale: _heartScale,
                                    child: _GlassIconButton(
                                      icon: entry.story.likedByMe
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: entry.story.likedByMe
                                          ? Colors.redAccent
                                          : Colors.white,
                                      onPressed: _toggleLike,
                                      tooltip: 'Харесай',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.entry,
    required this.progress,
    required this.isMine,
    required this.onDelete,
    required this.onClose,
  });

  final _FlatEntry entry;
  final AnimationController progress;
  final bool isMine;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: List.generate(entry.group.stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: progress,
                            builder: (context, _) {
                              final value = i < entry.indexInGroup
                                  ? 1.0
                                  : (i > entry.indexInGroup
                                        ? 0.0
                                        : progress.value);
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                        initials: entry.group.author.initials,
                        imageUrl: entry.group.author.avatarUrl,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          entry.group.author.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _relativeTime(entry.story.createdAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      if (isMine)
                        _GlassIconButton(
                          icon: Icons.delete_outline,
                          color: Colors.white,
                          onPressed: onDelete,
                          tooltip: 'Изтрий',
                        ),
                      const SizedBox(width: AppSpacing.xs),
                      _GlassIconButton(
                        icon: Icons.close,
                        color: Colors.white,
                        onPressed: onClose,
                        tooltip: 'Затвори',
                      ),
                    ],
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _ViewCountBar extends StatelessWidget {
  const _ViewCountBar({required this.viewCount, required this.onTap});

  final int viewCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.remove_red_eye_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _viewersLabel(viewCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewersSheet extends StatelessWidget {
  const _ViewersSheet({required this.viewers});

  final List<StoryViewer> viewers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.sm),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Видяно от ${viewers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: viewers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        'Все още никой не е видял тази история.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: viewers.length,
                      itemBuilder: (context, index) {
                        final viewer = viewers[index];
                        return ListTile(
                          leading: AppAvatar(
                            initials: viewer.profile.initials,
                            imageUrl: viewer.profile.avatarUrl,
                            size: 40,
                          ),
                          title: Text(
                            viewer.profile.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: Text(
                            _relativeTime(viewer.viewedAt),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
