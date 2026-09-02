import '../../contacts/domain/contact_models.dart';

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.otherUser,
    this.lastMessageBody,
    this.lastMessageSenderId,
    this.lastMessageAt,
  });

  final String id;
  final UserProfile otherUser;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
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

enum CallOutcome {
  /// Picked up — [ChatMessage.body] carries how long the call lasted.
  completed,

  /// Rang until it timed out; no one explicitly declined it.
  noAnswer,

  /// The other side explicitly declined it.
  declined,
}

/// Call-log entries are stored as regular messages with a reserved body,
/// encoding call type, outcome, and duration — so they show up in history
/// and previews without a schema change. The marker is plain ASCII (safe
/// for the DB, git, and every editor) and distinctive enough that no one
/// would type it by accident. Format: prefix, then
/// "video-or-audio:outcome-name:duration-in-seconds", where outcome-name
/// is a [CallOutcome] enum name.
class CallLogMessage {
  CallLogMessage._();

  static const _prefix = '::connectme-call::';

  // Superseded formats from earlier in development — kept only so old test
  // messages still render as something readable instead of raw text.
  static const _legacyVideoMarker = '::connectme-call-video::';
  static const _legacyAudioMarker = '::connectme-call-audio::';

  static String encode({
    required bool video,
    required CallOutcome outcome,
    Duration duration = Duration.zero,
  }) {
    final type = video ? 'video' : 'audio';
    return '$_prefix$type:${outcome.name}:${duration.inSeconds}';
  }

  static bool isCallLog(String body) =>
      body.startsWith(_prefix) ||
      body == _legacyVideoMarker ||
      body == _legacyAudioMarker;

  /// Human-readable text for a call-log body from the given viewer's
  /// perspective, or [body] unchanged if it isn't a call-log entry.
  static String display(
    String body, {
    required bool startedByMe,
    required String otherName,
  }) {
    final who = startedByMe ? 'Ти' : otherName;

    if (body == _legacyVideoMarker) return '📹 $who стартира видео разговор';
    if (body == _legacyAudioMarker) return '📞 $who стартира аудио разговор';
    if (!body.startsWith(_prefix)) return body;

    final parts = body.substring(_prefix.length).split(':');
    if (parts.length != 3) return body;

    final video = parts[0] == 'video';
    final seconds = int.tryParse(parts[2]) ?? 0;
    final icon = video ? '📹' : '📞';
    final kind = video ? 'видео' : 'аудио';

    switch (parts[1]) {
      case 'declined':
        return '$icon $who стартира $kind разговор — беше отказан';
      case 'noAnswer':
        return '$icon $who звъня, но нямаше отговор';
      default:
        final minutes = seconds ~/ 60;
        final secs = (seconds % 60).toString().padLeft(2, '0');
        return '$icon $who проведе $kind разговор · $minutes:$secs мин';
    }
  }
}

/// A view-once photo, stored as a regular message whose body encodes the
/// Storage object path (bucket `ephemeral-photos`) and whether it's been
/// opened yet. There's deliberately no persisted image once it's been
/// viewed — the app deletes the Storage object right after showing it, and
/// flips the body to the "viewed" marker so it can't be opened again.
class PhotoMessage {
  PhotoMessage._();

  static const _unviewedPrefix = '::connectme-photo::';
  static const _viewedMarker = '::connectme-photo-viewed::';

  static String encode(String storagePath) => '$_unviewedPrefix$storagePath';

  static String viewed() => _viewedMarker;

  static bool isPhoto(String body) =>
      body.startsWith(_unviewedPrefix) || body == _viewedMarker;

  static bool isViewed(String body) => body == _viewedMarker;

  /// The Storage object path to open, or null if [body] isn't an
  /// unviewed photo message.
  static String? storagePath(String body) {
    if (!body.startsWith(_unviewedPrefix)) return null;
    return body.substring(_unviewedPrefix.length);
  }
}

/// A voice message, stored as a regular message whose body encodes the
/// Storage object path (bucket `voice-messages`) and its duration. Unlike
/// photos, these are kept permanently — chat history should stay
/// replayable, same as text.
class VoiceMessage {
  VoiceMessage._();

  static const _prefix = '::connectme-voice::';

  static String encode(String storagePath, Duration duration) =>
      '$_prefix$storagePath:${duration.inSeconds}';

  static bool isVoice(String body) => body.startsWith(_prefix);

  /// The Storage object path to play, or null if [body] isn't a voice
  /// message.
  static String? storagePath(String body) {
    if (!body.startsWith(_prefix)) return null;
    final rest = body.substring(_prefix.length);
    final separator = rest.lastIndexOf(':');
    if (separator < 0) return null;
    return rest.substring(0, separator);
  }

  static Duration duration(String body) {
    if (!body.startsWith(_prefix)) return Duration.zero;
    final rest = body.substring(_prefix.length);
    final separator = rest.lastIndexOf(':');
    if (separator < 0) return Duration.zero;
    final seconds = int.tryParse(rest.substring(separator + 1)) ?? 0;
    return Duration(seconds: seconds);
  }
}

/// A reply to someone's story, delivered as a normal chat message so it
/// shows up in their inbox exactly like any other DM. The marker carries
/// which story was replied to (best-effort — the story itself may have
/// expired by the time it's read, in which case only the text survives)
/// and the reply text. Format: prefix, then "storyId::text" — the
/// storyId is a uuid (never contains "::"), so splitting on the first
/// occurrence is unambiguous even if the reply text itself contains "::".
class StoryReplyMessage {
  StoryReplyMessage._();

  static const _prefix = '::connectme-story-reply::';

  static String encode({required String storyId, required String text}) =>
      '$_prefix$storyId::$text';

  static bool isStoryReply(String body) => body.startsWith(_prefix);

  static String? text(String body) {
    if (!body.startsWith(_prefix)) return null;
    final rest = body.substring(_prefix.length);
    final separator = rest.indexOf('::');
    if (separator < 0) return null;
    return rest.substring(separator + 2);
  }

  /// Human-readable text for a story-reply body from the given viewer's
  /// perspective, or null if [body] isn't a story-reply.
  static String? display(
    String body, {
    required bool startedByMe,
    required String otherName,
  }) {
    final replyText = text(body);
    if (replyText == null) return null;
    final header = startedByMe
        ? 'Отговори на историята на $otherName'
        : 'Отговори на историята ти';
    return '↩️ $header\n$replyText';
  }
}

class ChatFailure implements Exception {
  const ChatFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
