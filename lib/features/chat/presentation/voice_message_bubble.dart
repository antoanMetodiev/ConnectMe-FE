import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/chat_controller.dart';

/// A permanent, replayable voice message bubble — fetches a fresh signed
/// playback URL each time it's played (the file itself lives in Storage
/// indefinitely).
class VoiceMessageBubble extends ConsumerStatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.isMine,
    required this.storagePath,
    required this.duration,
  });

  final bool isMine;
  final String storagePath;
  final Duration duration;

  @override
  ConsumerState<VoiceMessageBubble> createState() =>
      _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<VoiceMessageBubble> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  bool _loading = false;
  bool _playing = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _positionSub = _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await ref
          .read(chatRepositoryProvider)
          .voicePlaybackUrl(widget.storagePath);
      await _player.play(UrlSource(url));
      if (mounted) {
        setState(() {
          _playing = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = widget.isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    final totalMs = widget.duration.inMilliseconds;
    final progress = totalMs == 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final remaining = _playing ? widget.duration - _position : widget.duration;
    final shownSeconds = remaining.isNegative ? 0 : remaining.inSeconds;
    final mm = (shownSeconds ~/ 60).toString();
    final ss = (shownSeconds % 60).toString().padLeft(2, '0');

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: widget.isMine
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _toggle,
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: foreground,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  color: foreground,
                  backgroundColor: foreground.withValues(alpha: 0.25),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$mm:$ss',
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
