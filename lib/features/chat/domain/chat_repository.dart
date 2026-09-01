import 'chat_models.dart';

abstract class ChatRepository {
  /// Chats the current user is part of, newest activity first.
  Future<List<ChatSummary>> listChats();

  /// Live-updating version of [listChats] — re-emits whenever a message
  /// changes in any of the user's chats, so previews and ordering stay
  /// current without the caller having to manually refresh.
  Stream<List<ChatSummary>> watchChats();

  /// Finds the existing 1:1 chat with [otherUserId], or creates one.
  Future<String> findOrCreateChat(String otherUserId);

  /// Live-updating window of the [limit] most recent messages, newest
  /// first. Raise [limit] to page further back into history.
  Stream<List<ChatMessage>> watchMessages(String chatId, {required int limit});

  Future<void> sendMessage({required String chatId, required String body});

  /// Broadcasts a one-shot "I'm typing" signal to the other participant.
  void sendTyping(String chatId);

  /// Emits true while [otherUserId] is typing in this chat, false once
  /// their signal goes quiet.
  Stream<bool> watchOtherTyping({
    required String chatId,
    required String otherUserId,
  });

  /// Marks the chat as read by the current user, right now.
  Future<void> markChatRead(String chatId);

  /// When [otherUserId] last read this chat, updated live.
  Stream<DateTime?> watchOtherLastRead({
    required String chatId,
    required String otherUserId,
  });
}
