import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../application/auth_controller.dart';
import '../application/post_auth_route.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;

  @override
  void initState() {
    super.initState();
    final current = ref.read(authControllerProvider).value;
    _displayName = TextEditingController(text: current?.displayName ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .completeProfileSetup(displayName: _displayName.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen(authControllerProvider, (previous, next) {
      if (previous == null || !previous.isLoading) return;
      next.whenOrNull(
        data: (user) {
          if (user != null) context.go(postAuthRoute(user));
        },
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    final isLoading = ref.watch(authControllerProvider).isLoading;
    final name = _displayName.text.trim();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Center(child: AppAvatar(initials: initials, size: 72)),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Как да те наричаме?',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Профилна снимка ще можеш да добавиш малко по-късно.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                TextFormField(
                  controller: _displayName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Име'),
                  validator: Validators.displayName,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppPrimaryButton(
                  label: 'Продължи',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
