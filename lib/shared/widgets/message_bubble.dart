import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMine,
  });

  final String text;
  final String time;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final background = isMine ? colors.bubbleSent : colors.bubbleReceived;
    final foreground = isMine ? colors.onBubbleSent : colors.onBubbleReceived;
    final timeColor = isMine
        ? colors.onBubbleSent.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border:
              isMine ? null : Border.all(color: colors.bubbleReceivedBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: theme.textTheme.labelSmall?.copyWith(color: timeColor),
            ),
          ],
        ),
      ),
    );
  }
}
