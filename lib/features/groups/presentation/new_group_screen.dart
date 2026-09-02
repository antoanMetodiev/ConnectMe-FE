import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../contacts/application/contacts_controller.dart';
import '../../contacts/domain/contact_models.dart';
import '../application/groups_controller.dart';

/// Creates a persistent text group — any registered user can be added, not
/// just existing contacts. Calling only becomes available afterwards, from
/// inside the group's chat screen.
class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  final Map<String, UserProfile> _selected = {};
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(anyUserSearchControllerProvider.notifier).search(value);
    });
  }

  void _toggle(UserProfile profile) {
    setState(() {
      if (_selected.containsKey(profile.id)) {
        _selected.remove(profile.id);
      } else {
        _selected[profile.id] = profile;
      }
    });
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дай име на групата.')),
      );
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добави поне един човек в групата.')),
      );
      return;
    }
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final groupId = await ref
          .read(groupsRepositoryProvider)
          .createGroup(name: name, memberIds: _selected.keys.toList());
      if (mounted) context.pushReplacement('/group/$groupId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(anyUserSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Нова група'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: const Text('Създай'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Име на групата',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Добави хора по име или имейл',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _selected.values
                    .map(
                      (profile) => Chip(
                        avatar: AppAvatar(
                          initials: profile.initials,
                          imageUrl: profile.avatarUrl,
                          size: 24,
                        ),
                        label: Text(profile.name),
                        onDeleted: () => _toggle(profile),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (_searchController.text.trim().isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        'Търси хора по име или имейл — могат да са '
                        'абсолютно всеки регистриран потребител, не само '
                        'контакти.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'Няма намерени потребители.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final profile = results[index];
                    final isSelected = _selected.containsKey(profile.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => _toggle(profile),
                      secondary: AppAvatar(
                        initials: profile.initials,
                        imageUrl: profile.avatarUrl,
                      ),
                      title: Text(profile.name),
                      subtitle: Text(profile.email),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  '$error',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
