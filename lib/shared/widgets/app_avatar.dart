import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum PresenceStatus { none, online, offline }

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    this.presence = PresenceStatus.none,
    this.size = 40,
  });

  final String initials;
  final PresenceStatus presence;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              initials,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          if (presence == PresenceStatus.online)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: colors.online,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
