import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stream_video/stream_video.dart' as stream;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/chat_controller.dart';
import '../../chat/domain/chat_models.dart';

/// Connects the Stream Video client for the signed-in user and keeps it
/// alive for the app session — reconnects on sign-in, disconnects on
/// sign-out. Every other call provider watches this rather than managing
/// its own connection.
class StreamVideoConnection extends AsyncNotifier<stream.StreamVideo?> {
  @override
  FutureOr<stream.StreamVideo?> build() async {
    final authUser = ref.watch(authControllerProvider).value;
    if (authUser == null || !Env.isStreamConfigured) return null;

    final response = await supabase.Supabase.instance.client.functions
        .invoke('stream-token');
    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;

    final video = stream.StreamVideo(
      Env.streamApiKey,
      user: stream.User.regular(
        userId: authUser.id,
        name: (authUser.displayName?.isNotEmpty ?? false)
            ? authUser.displayName!
            : authUser.email,
      ),
      userToken: token,
    );

    ref.onDispose(() {
      video.disconnect();
    });

    return video;
  }
}

final streamVideoConnectionProvider =
    AsyncNotifierProvider<StreamVideoConnection, stream.StreamVideo?>(
      StreamVideoConnection.new,
    );

/// Emits an incoming call while the app is open and connected. This is
/// foreground-only — there's no push-notification setup yet, so a call
/// that arrives while the app is backgrounded or closed won't ring.
final incomingCallProvider = StreamProvider<stream.Call?>((ref) async* {
  final video = await ref.watch(streamVideoConnectionProvider.future);
  if (video == null) {
    yield null;
    return;
  }
  yield* video.state.incomingCall.valueStream;
});

class CallActions {
  CallActions(this._ref);

  final Ref _ref;

  Future<stream.Call> startCall({
    required String chatId,
    required String otherUserId,
    required bool video,
  }) async {
    final client = await _ref.read(streamVideoConnectionProvider.future);
    if (client == null) {
      throw StateError('Видео разговорите не са налични.');
    }
    final myId = supabase.Supabase.instance.client.auth.currentUser!.id;
    final call = client.makeCall(
      callType: stream.StreamCallType.defaultType(),
      id: const Uuid().v4(),
    );
    await call.getOrCreate(
      memberIds: [myId, otherUserId],
      video: video,
      ringing: true,
    );

    // Best-effort — a failed log entry shouldn't block the call itself.
    unawaited(
      _ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chatId: chatId,
            body: video ? CallLogMessage.video() : CallLogMessage.audio(),
          ),
    );

    return call;
  }
}

final callActionsProvider = Provider((ref) => CallActions(ref));
