import '../../contacts/domain/contact_models.dart';

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.otherUser,
    this.lastMessageBody,
    this.lastMessageAt,
  });

  final String id;
  final UserProfile otherUser;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

/// Call-log entries are stored as regular messages with a reserved body,
/// so they show up in history and previews without a schema change. The
/// marker is plain ASCII (safe for the DB, git, and every editor) and
/// distinctive enough that no one would type it by accident.
class CallLogMessage {
  CallLogMessage._();

  static const _videoMarker = '::connectme-call-video::';
  static const _audioMarker = '::connectme-call-audio::';

  static String video() => _videoMarker;
  static String audio() => _audioMarker;

  static bool isCallLog(String body) =>
      body == _videoMarker || body == _audioMarker;

  /// Human-readable text for a call-log body, or [body] unchanged if it
  /// isn't one — safe to call on any message body.
  static String display(String body) {
    if (body == _videoMarker) return '📹 Видео разговор';
    if (body == _audioMarker) return '📞 Аудио разговор';
    return body;
  }
}

class ChatFailure implements Exception {
  const ChatFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
