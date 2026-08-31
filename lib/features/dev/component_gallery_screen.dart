import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_primary_button.dart';
import '../../shared/widgets/message_bubble.dart';
import '../../shared/widgets/message_input_bar.dart';

class _DemoMessage {
  _DemoMessage(this.text, this.time, this.isMine);

  final String text;
  final String time;
  final bool isMine;
}

/// Internal style guide: exercises the design-system widgets together so
/// changes to tokens/components can be checked in one place while the real
/// screens are still being built.
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() =>
      _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  final _controller = TextEditingController();
  final _messages = [
    _DemoMessage('Ще стигнеш ли до 7?', '14:02', false),
    _DemoMessage('Да, тръгвам сега 🙂', '14:03', true),
    _DemoMessage('Готино, чакам те!', '14:03', false),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_DemoMessage(text, 'сега', true));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            const AppAvatar(initials: 'М', presence: PresenceStatus.online),
            const SizedBox(width: AppSpacing.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Мария', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'На линия',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppPrimaryButton(label: 'Ново съобщение', onPressed: () {}),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              itemCount: _messages.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final m = _messages[index];
                return MessageBubble(
                  text: m.text,
                  time: m.time,
                  isMine: m.isMine,
                );
              },
            ),
          ),
          MessageInputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}
