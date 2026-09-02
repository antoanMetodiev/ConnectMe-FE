import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class MessageInputBar extends StatelessWidget {
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onRecord,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// Shows a leading attachment button when provided; omitted entirely
  /// otherwise, so existing call sites are unaffected.
  final VoidCallback? onAttach;

  /// Shows a leading mic button when provided, to start recording a voice
  /// message.
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            if (onAttach != null) ...[
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.camera_alt_outlined),
                tooltip: 'Изпрати снимка (отваря се веднъж)',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (onRecord != null) ...[
              IconButton(
                onPressed: onRecord,
                icon: const Icon(Icons.mic_none_outlined),
                tooltip: 'Гласово съобщение',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Съобщение…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _SendButton(onPressed: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.send_rounded,
            size: 18,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
