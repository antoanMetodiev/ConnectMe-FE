import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../application/contacts_controller.dart';

class ContactActivityScreen extends ConsumerStatefulWidget {
  const ContactActivityScreen({super.key});

  @override
  ConsumerState<ContactActivityScreen> createState() =>
      _ContactActivityScreenState();
}

class _ContactActivityScreenState
    extends ConsumerState<ContactActivityScreen> {
  @override
  void dispose() {
    // Mark on the way out, not on open — removing entries while the user is
    // still looking at them would be jarring. They simply won't be there
    // next time this list loads.
    ref.read(contactActivityControllerProvider.notifier).markLoadedAsSeen();
    ref.invalidate(contactActivityControllerProvider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activityAsync = ref.watch(contactActivityControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Известия')),
      body: activityAsync.when(
        data: (activity) {
          if (activity.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Няма нови известия за покани.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: activity.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final a = activity[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: AppAvatar(
                  initials: a.profile.initials,
                  imageUrl: a.profile.avatarUrl,
                ),
                title: Text(a.profile.name),
                subtitle: Text(
                  a.accepted
                      ? 'Прие поканата ти'
                      : 'Отказа поканата ти',
                ),
                trailing: Icon(
                  a.accepted ? Icons.check_circle : Icons.cancel,
                  color: a.accepted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
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
      ),
    );
  }
}
