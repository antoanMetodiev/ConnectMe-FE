import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video/stream_video.dart' as stream;
import 'package:stream_video_flutter/stream_video_flutter.dart' as stream_ui;

import '../data/ringtone_player.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.call});

  final stream_ui.Call call;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _ringtonePlayer = RingtonePlayer();
  StreamSubscription<stream.CallStatus>? _statusSubscription;

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
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: stream_ui.StreamCallContainer(
          call: widget.call,
          onBackPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
