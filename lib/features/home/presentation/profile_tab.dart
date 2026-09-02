import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../auth/application/auth_controller.dart';

String _formatJoinDate(DateTime date) {
  const months = [
    'януари',
    'февруари',
    'март',
    'април',
    'май',
    'юни',
    'юли',
    'август',
    'септември',
    'октомври',
    'ноември',
    'декември',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year} г.';
}

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
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
        imageQuality: 80,
        maxWidth: 800,
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

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final notifier = ref.read(authControllerProvider.notifier);
      final url = await notifier.uploadAvatar(bytes);
      await notifier.updateProfile(avatarUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Промяна на име'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Име'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отказ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Запази'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(displayName: newName);
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
    final user = ref.watch(authControllerProvider).value;
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email ?? '');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(initials: initials, imageUrl: user?.avatarUrl, size: 88),
              if (_uploadingAvatar)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _uploadingAvatar ? null : _changeAvatar,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => _editName(name),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Промени име',
            ),
          ],
        ),
        if (user?.email != null)
          Text(
            user!.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Имейл'),
                subtitle: Text(user?.email ?? '—'),
              ),
              if (user?.createdAt != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Член от'),
                  subtitle: Text(_formatJoinDate(user!.createdAt!)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppPrimaryButton(
          label: 'Изход',
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
