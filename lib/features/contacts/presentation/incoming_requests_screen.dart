import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../application/contacts_controller.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    bool accept,
  ) async {
    try {
      await ref
          .read(incomingRequestsControllerProvider.notifier)
          .respond(requestId: requestId, accept: accept);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requestsAsync = ref.watch(incomingRequestsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Входящи покани')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Няма чакащи покани.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = requests[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: AppAvatar(
                  initials: r.profile.initials,
                  imageUrl: r.profile.avatarUrl,
                ),
                title: Text(r.profile.name),
                subtitle: Text(r.profile.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () =>
                          _respond(context, ref, r.requestId!, false),
                      icon: const Icon(Icons.close),
                      tooltip: 'Откажи',
                    ),
                    IconButton(
                      onPressed: () =>
                          _respond(context, ref, r.requestId!, true),
                      icon: const Icon(Icons.check),
                      tooltip: 'Приеми',
                    ),
                  ],
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
