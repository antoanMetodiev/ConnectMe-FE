import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../stories/application/stories_controller.dart';
import '../../stories/domain/story_models.dart';

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'току-що';
  if (diff.inMinutes < 60) return 'преди ${diff.inMinutes} мин';
  return 'преди ${diff.inHours} ч';
}

String _extensionFor(XFile file, {required bool isVideo}) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    return name.substring(dot + 1).toLowerCase();
  }
  return isVideo ? 'mp4' : 'jpg';
}

class StoriesTab extends ConsumerStatefulWidget {
  const StoriesTab({super.key});

  @override
  ConsumerState<StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends ConsumerState<StoriesTab> {
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Best-effort — frees storage from stories of mine that already expired.
    Future.microtask(
      () => ref
          .read(storiesRepositoryProvider)
          .deleteExpiredMine()
          .catchError((_) {}),
    );
  }

  Future<void> _addStory() async {
    final pick = await showModalBottomSheet<({ImageSource source, bool video})>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStorySheet(
        onPick: (source, video) =>
            Navigator.pop(context, (source: source, video: video)),
      ),
    );
    if (pick == null || !mounted) return;

    XFile? picked;
    try {
      picked = pick.video
          ? await ImagePicker().pickVideo(
              source: pick.source,
              maxDuration: const Duration(seconds: 60),
            )
          : await ImagePicker().pickImage(
              source: pick.source,
              imageQuality: 75,
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

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = _extensionFor(picked, isVideo: pick.video);
      await ref
          .read(storiesRepositoryProvider)
          .uploadStory(
            bytes: bytes,
            mediaType: pick.video ? StoryMediaType.video : StoryMediaType.image,
            extension: extension,
            contentType:
                picked.mimeType ?? (pick.video ? 'video/mp4' : 'image/jpeg'),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openViewer(List<StoryGroup> groups, int startIndex) {
    context.push(
      '/stories/view',
      extra: (groups: groups, startIndex: startIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(storyGroupsProvider);
    final myId = ref.watch(authControllerProvider).value?.id;

    return groupsAsync.when(
      data: (groups) {
        StoryGroup? myGroup;
        final others = <StoryGroup>[];
        for (final group in groups) {
          if (group.author.id == myId) {
            myGroup = group;
          } else {
            others.add(group);
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _MyStoryRow(
                group: myGroup,
                uploading: _uploading,
                onAdd: _addStory,
                onOpen: myGroup == null
                    ? null
                    : () => _openViewer(groups, groups.indexOf(myGroup!)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (others.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'ПРИЯТЕЛИ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (others.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                ),
                child: Text(
                  'Все още никой от контактите ти няма активна история.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...others.map(
                (group) => _StoryTile(
                  group: group,
                  onTap: () => _openViewer(groups, groups.indexOf(group)),
                ),
              ),
          ],
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

/// The gradient/muted "story ring" every avatar in this tab wears — bright
/// gradient for something new to see, a plain muted ring once it's all
/// been seen. [active] with [seen] = false always renders the gradient
/// (used for "my story", which has no seen/unseen concept of its own).
class _StoryRing extends StatelessWidget {
  const _StoryRing({
    required this.child,
    required this.active,
    this.seen = false,
  });

  final Widget child;
  final bool active;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    if (!active) {
      return Padding(padding: const EdgeInsets.all(2), child: child);
    }

    return Container(
      padding: const EdgeInsets.all(2.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: seen
            ? null
            : SweepGradient(
                colors: [
                  theme.colorScheme.primary,
                  colors.online,
                  theme.colorScheme.primary,
                ],
              ),
        border: seen ? Border.all(color: theme.dividerColor, width: 2) : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.scaffoldBackgroundColor,
        ),
        child: child,
      ),
    );
  }
}

class _AddStorySheet extends StatelessWidget {
  const _AddStorySheet({required this.onPick});

  final void Function(ImageSource source, bool video) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
                color: theme.dividerColor,
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Нова история',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Направи снимка',
              onTap: () => onPick(ImageSource.camera, false),
            ),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Снимка от галерията',
              onTap: () => onPick(ImageSource.gallery, false),
            ),
            _SheetOption(
              icon: Icons.videocam_outlined,
              label: 'Заснеми видео',
              onTap: () => onPick(ImageSource.camera, true),
            ),
            _SheetOption(
              icon: Icons.video_library_outlined,
              label: 'Видео от галерията',
              onTap: () => onPick(ImageSource.gallery, true),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _MyStoryRow extends StatelessWidget {
  const _MyStoryRow({
    required this.group,
    required this.uploading,
    required this.onAdd,
    required this.onOpen,
  });

  final StoryGroup? group;
  final bool uploading;
  final VoidCallback onAdd;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = group?.author;
    final viewCount = group == null
        ? 0
        : group!.stories.fold<int>(0, (sum, s) => sum + s.viewCount);

    return InkWell(
      onTap: onOpen ?? (uploading ? null : onAdd),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _StoryRing(
                  active: group != null,
                  child: AppAvatar(
                    initials: author?.initials ?? '?',
                    imageUrl: author?.avatarUrl,
                    size: 56,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: uploading ? null : onAdd,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: uploading
                            ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Icon(
                                Icons.add,
                                size: 14,
                                color: theme.colorScheme.onPrimary,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Моята история', style: theme.textTheme.titleMedium),
                  Text(
                    group == null
                        ? 'Добави снимка или видео'
                        : '${group!.stories.length} · ${_relativeTime(group!.stories.last.createdAt)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (group != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$viewCount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.group, required this.onTap});

  final StoryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = group.stories.last;

    return ListTile(
      onTap: onTap,
      leading: _StoryRing(
        active: true,
        seen: group.allSeenByMe,
        child: AppAvatar(
          initials: group.author.initials,
          imageUrl: group.author.avatarUrl,
          size: 52,
        ),
      ),
      title: Text(
        group.author.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: group.allSeenByMe ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${group.stories.length} · ${_relativeTime(latest.createdAt)}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
