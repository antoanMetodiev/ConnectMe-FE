import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/supabase_chat_repository.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(supabase.Supabase.instance.client);
});

final chatListProvider = StreamProvider.autoDispose<List<ChatSummary>>((ref) {
  return ref.read(chatRepositoryProvider).watchChats();
});

const chatMessagePageSize = 20;

/// How many messages are currently loaded for a chat — starts at one page
/// and grows as the user scrolls further into history.
final chatMessageLimitProvider = StateProvider.autoDispose.family<int, String>(
  (ref, chatId) => chatMessagePageSize,
);

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      final limit = ref.watch(chatMessageLimitProvider(chatId));
      return ref.read(chatRepositoryProvider).watchMessages(chatId, limit: limit);
    });

typedef _ChatParticipants = ({String chatId, String otherUserId});

final chatOtherTypingProvider = StreamProvider.autoDispose
    .family<bool, _ChatParticipants>((ref, args) {
      return ref
          .read(chatRepositoryProvider)
          .watchOtherTyping(chatId: args.chatId, otherUserId: args.otherUserId);
    });

final chatOtherLastReadProvider = StreamProvider.autoDispose
    .family<DateTime?, _ChatParticipants>((ref, args) {
      return ref
          .read(chatRepositoryProvider)
          .watchOtherLastRead(
            chatId: args.chatId,
            otherUserId: args.otherUserId,
          );
    });
