import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video/stream_video.dart' as stream;
import 'package:stream_video_flutter/stream_video_flutter.dart' as stream_ui;

import '../../chat/domain/chat_models.dart';
import '../data/ringtone_player.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.call,
    this.outgoingCallLog,
  });

  final stream_ui.Call call;

  /// Present only for the side that placed the call — that's who logs the
  /// outcome (declined / no answer / completed + duration) into the chat
  /// once the call ends, so it isn't logged twice.
  final OutgoingCallLog? outgoingCallLog;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

/// What [CallScreen] needs to know to write the call-log entry once an
/// outgoing call ends. [writeMessage] is conversation-agnostic — it's the
/// caller's job to point it at a 1:1 chat or a group.
class OutgoingCallLog {
  const OutgoingCallLog({required this.video, required this.writeMessage});

  final bool video;
  final Future<void> Function(String body) writeMessage;
}

class _CallScreenState extends State<CallScreen> {
  final _ringtonePlayer = RingtonePlayer();
  StreamSubscription<stream.CallStatus>? _statusSubscription;
  DateTime? _connectedAt;
  bool _wasConnected = false;
  bool _logged = false;
  bool _sharingScreen = false;

  @override
  void initState() {
    super.initState();
    _statusSubscription = widget.call.state.valueStream
        .map((state) => state.status)
        .distinct()
        .listen(_onStatusChanged);
  }

  void _onStatusChanged(stream.CallStatus status) {
    if (status.isOutgoing) {
      _ringtonePlayer.play(RingtoneKind.outgoing);
    } else if (status.isIncoming) {
      _ringtonePlayer.play(RingtoneKind.incoming);
    } else {
      _ringtonePlayer.stop();
    }

    if ((status.isConnected || status.isJoined) && _connectedAt == null) {
      _connectedAt = DateTime.now();
      _wasConnected = true;
    }

    if (status is stream.CallStatusDisconnected) {
      _logCallOutcome(status.reason);
    }
  }

  void _logCallOutcome(stream.DisconnectReason reason) {
    final log = widget.outgoingCallLog;
    if (log == null || _logged) return;
    _logged = true;

    final CallOutcome outcome;
    var duration = Duration.zero;
    if (_wasConnected && _connectedAt != null) {
      outcome = CallOutcome.completed;
      duration = DateTime.now().difference(_connectedAt!);
    } else if (reason is stream.DisconnectReasonRejected) {
      outcome = CallOutcome.declined;
    } else {
      outcome = CallOutcome.noAnswer;
    }

    // Best-effort — a failed log entry shouldn't surface as an error to a
    // user who's just finished a call.
    unawaited(
      log.writeMessage(
        CallLogMessage.encode(
          video: log.video,
          outcome: outcome,
          duration: duration,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    if (_sharingScreen) {
      widget.call.setScreenShareEnabled(enabled: false);
    }
    _ringtonePlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleScreenShare() async {
    final next = !_sharingScreen;
    final result = await widget.call.setScreenShareEnabled(enabled: next);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _sharingScreen = next);
      return;
    }
    // Most commonly hit on a mobile browser — phones can't share their
    // screen to a website, only desktop browsers (Chrome/Edge/Firefox) can.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Споделянето на екран не се поддържа тук — работи само от '
          'десктоп браузър (не от телефон).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: stream_ui.StreamCallContainer(
          call: widget.call,
          onBackPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'screen-share',
          onPressed: _toggleScreenShare,
          backgroundColor: _sharingScreen
              ? theme.colorScheme.error
              : theme.colorScheme.surface,
          foregroundColor: _sharingScreen
              ? theme.colorScheme.onError
              : theme.colorScheme.onSurface,
          tooltip: _sharingScreen
              ? 'Спри споделянето на екрана'
              : 'Сподели екрана (само от компютър)',
          child: Icon(
            _sharingScreen ? Icons.stop_screen_share : Icons.screen_share,
          ),
        ),
      ),
    );
  }
}
