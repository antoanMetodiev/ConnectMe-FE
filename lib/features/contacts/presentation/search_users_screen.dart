import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../application/contacts_controller.dart';
import '../domain/contact_models.dart';

class SearchUsersScreen extends ConsumerStatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  ConsumerState<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends ConsumerState<SearchUsersScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // reflect the new text immediately in the empty-state check
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(contactsSearchControllerProvider.notifier).search(value);
    });
  }

  Future<void> _sendRequest(String userId) async {
    try {
      await ref
          .read(contactsSearchControllerProvider.notifier)
          .sendRequest(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _respond(String requestId, bool accept) async {
    try {
      await ref
          .read(contactsSearchControllerProvider.notifier)
          .respond(requestId: requestId, accept: accept);
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
    final resultsAsync = ref.watch(contactsSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Търси по име или имейл',
            border: InputBorder.none,
          ),
        ),
      ),
      body: resultsAsync.when(
        data: (results) {
          if (_controller.text.trim().isEmpty) {
            return _EmptyState(text: 'Потърси хора по име или имейл.');
          }
          if (results.isEmpty) {
            return const _EmptyState(text: 'Няма намерени потребители.');
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = results[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: AppAvatar(initials: r.profile.initials),
                title: Text(r.profile.name),
                subtitle: Text(r.profile.email),
                trailing: _Action(
                  result: r,
                  onSend: () => _sendRequest(r.profile.id),
                  onRespond: (accept) => _respond(r.requestId!, accept),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _EmptyState(
          text: '$error',
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.result,
    required this.onSend,
    required this.onRespond,
  });

  final ContactSearchResult result;
  final VoidCallback onSend;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (result.status) {
      case ContactStatus.none:
        return TextButton(onPressed: onSend, child: const Text('Добави'));
      case ContactStatus.pendingSent:
        return Text(
          'Поканата е изпратена',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      case ContactStatus.pendingReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => onRespond(false),
              icon: const Icon(Icons.close),
              tooltip: 'Откажи',
            ),
            IconButton(
              onPressed: () => onRespond(true),
              icon: const Icon(Icons.check),
              tooltip: 'Приеми',
            ),
          ],
        );
      case ContactStatus.accepted:
        return Text(
          'Контакт',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
