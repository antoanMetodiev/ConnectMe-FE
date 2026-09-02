import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../contacts/domain/contact_models.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

const _ephemeralPhotosBucket = 'ephemeral-photos';
const _voiceMessagesBucket = 'voice-messages';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final supabase.SupabaseClient _client;

  final Map<String, supabase.RealtimeChannel> _typingChannels = {};

  String get _myId => _client.auth.currentUser!.id;

  @override
  Future<List<ChatSummary>> listChats() async {
    final chatRows = await _client
        .from('chats')
        .select()
        .or('user_a_id.eq.$_myId,user_b_id.eq.$_myId');

    if (chatRows.isEmpty) return [];

    final otherIdByChatId = {
      for (final row in chatRows)
        row['id'] as String: row['user_a_id'] == _myId
            ? row['user_b_id'] as String
            : row['user_a_id'] as String,
    };

    final profilesById = await _profilesById(otherIdByChatId.values.toList());

    final chatIds = chatRows.map((r) => r['id'] as String).toList();
    final messageRows = await _client
        .from('messages')
        .select()
        .inFilter('chat_id', chatIds)
        .order('created_at', ascending: false);

    final latestByChatId = <String, Map<String, dynamic>>{};
    for (final row in messageRows) {
      latestByChatId.putIfAbsent(row['chat_id'] as String, () => row);
    }

    final summaries = chatRows
        .map((row) {
          final chatId = row['id'] as String;
          final otherUser = profilesById[otherIdByChatId[chatId]];
          if (otherUser == null) return null;
          final lastMessage = latestByChatId[chatId];
          return ChatSummary(
            id: chatId,
            otherUser: otherUser,
            lastMessageBody: lastMessage?['body'] as String?,
            lastMessageSenderId: lastMessage?['sender_id'] as String?,
            lastMessageAt: lastMessage != null
                ? DateTime.parse(lastMessage['created_at'] as String)
                : DateTime.parse(row['created_at'] as String),
          );
        })
        .whereType<ChatSummary>()
        .toList();

    summaries.sort((a, b) {
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return summaries;
  }

  @override
  Stream<List<ChatSummary>> watchChats() async* {
    yield await listChats();
    // Re-run the aggregate query on every message change visible to this
    // user (RLS scopes it to their own chats) — this is what keeps the
    // list's last-message preview and most-recent-first order live instead
    // of freezing at whatever it was when the tab first loaded.
    await for (final _ in _client.from('messages').stream(primaryKey: ['id'])) {
      yield await listChats();
    }
  }

  @override
  Future<String> findOrCreateChat(String otherUserId) async {
    final ids = [_myId, otherUserId]..sort();
    final userAId = ids[0];
    final userBId = ids[1];

    final existing = await _client
        .from('chats')
        .select()
        .eq('user_a_id', userAId)
        .eq('user_b_id', userBId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    try {
      final inserted = await _client
          .from('chats')
          .insert({'user_a_id': userAId, 'user_b_id': userBId})
          .select()
          .single();
      return inserted['id'] as String;
    } on supabase.PostgrestException catch (e) {
      if (e.code == '23505') {
        // Lost a race with a concurrent insert — the chat exists now.
        final row = await _client
            .from('chats')
            .select()
            .eq('user_a_id', userAId)
            .eq('user_b_id', userBId)
            .single();
        return row['id'] as String;
      }
      throw ChatFailure(e.message);
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId, {required int limit}) {
    // ascending: false + limit keeps this a live-updating "N most recent
    // messages" window — the underlying stream re-sorts and re-caps on
    // every insert, so raising [limit] (to page further into history) just
    // means re-subscribing with a bigger window.
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map(
                (r) => ChatMessage(
                  id: r['id'] as String,
                  chatId: r['chat_id'] as String,
                  senderId: r['sender_id'] as String,
                  body: r['body'] as String,
                  createdAt: DateTime.parse(r['created_at'] as String),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    try {
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': _myId,
        'body': trimmed,
      });
    } on supabase.PostgrestException catch (e) {
      throw ChatFailure(e.message);
    }
  }

  supabase.RealtimeChannel _typingChannel(String chatId) {
    return _typingChannels.putIfAbsent(chatId, () {
      final channel = _client.channel('typing:$chatId');
      channel.subscribe();
      return channel;
    });
  }

  @override
  void sendTyping(String chatId) {
    _typingChannel(
      chatId,
    ).sendBroadcastMessage(event: 'typing', payload: {'sender_id': _myId});
  }

  @override
  Stream<bool> watchOtherTyping({
    required String chatId,
    required String otherUserId,
  }) {
    Timer? resetTimer;
    late final StreamController<bool> controller;
    controller = StreamController<bool>.broadcast(
      onCancel: () => resetTimer?.cancel(),
    );
    _typingChannel(chatId).onBroadcast(
      event: 'typing',
      callback: (payload) {
        if (payload['sender_id'] != otherUserId) return;
        controller.add(true);
        resetTimer?.cancel();
        resetTimer = Timer(const Duration(seconds: 3), () {
          if (!controller.isClosed) controller.add(false);
        });
      },
    );
    return controller.stream;
  }

  @override
  Future<void> markChatRead(String chatId) async {
    await _client.from('chat_reads').upsert({
      'chat_id': chatId,
      'user_id': _myId,
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Stream<DateTime?> watchOtherLastRead({
    required String chatId,
    required String otherUserId,
  }) {
    return _client
        .from('chat_reads')
        .stream(primaryKey: ['chat_id', 'user_id'])
        .eq('chat_id', chatId)
        .map((rows) {
          for (final row in rows) {
            if (row['user_id'] == otherUserId) {
              return DateTime.parse(row['last_read_at'] as String);
            }
          }
          return null;
        });
  }

  @override
  Future<void> sendPhoto({
    required String chatId,
    required Uint8List bytes,
  }) async {
    final path = '$chatId/${const Uuid().v4()}.jpg';
    try {
      await _client.storage
          .from(_ephemeralPhotosBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const supabase.FileOptions(
              contentType: 'image/jpeg',
            ),
          );
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': _myId,
        'body': PhotoMessage.encode(path),
      });
    } on supabase.StorageException catch (e) {
      throw ChatFailure(e.message);
    } on supabase.PostgrestException catch (e) {
      throw ChatFailure(e.message);
    }
  }

  @override
  Future<Uint8List> openPhoto({
    required String messageId,
    required String storagePath,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await _client.storage
          .from(_ephemeralPhotosBucket)
          .download(storagePath);
    } on supabase.StorageException catch (e) {
      throw ChatFailure(e.message);
    }

    // Best-effort cleanup — the viewer already has the bytes, so a hiccup
    // here shouldn't stop them from seeing the photo. Worst case it can be
    // reopened once, or the file lingers until a manual cleanup.
    try {
      await _client
          .from('messages')
          .update({'body': PhotoMessage.viewed()})
          .eq('id', messageId);
    } catch (_) {
      // Ignored — see comment above.
    }
    try {
      await _client.storage.from(_ephemeralPhotosBucket).remove([
        storagePath,
      ]);
    } catch (_) {
      // Ignored — see comment above.
    }

    return bytes;
  }

  @override
  Future<void> sendVoice({
    required String chatId,
    required Uint8List bytes,
    required Duration duration,
  }) async {
    final path = '$chatId/${const Uuid().v4()}.m4a';
    try {
      await _client.storage
          .from(_voiceMessagesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const supabase.FileOptions(contentType: 'audio/mp4'),
          );
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': _myId,
        'body': VoiceMessage.encode(path, duration),
      });
    } on supabase.StorageException catch (e) {
      throw ChatFailure(e.message);
    } on supabase.PostgrestException catch (e) {
      throw ChatFailure(e.message);
    }
  }

  @override
  Future<String> voicePlaybackUrl(String storagePath) async {
    try {
      return await _client.storage
          .from(_voiceMessagesBucket)
          .createSignedUrl(storagePath, 60 * 60);
    } on supabase.StorageException catch (e) {
      throw ChatFailure(e.message);
    }
  }

  Future<Map<String, UserProfile>> _profilesById(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('profiles')
        .select()
        .inFilter('id', ids.toSet().toList());
    return {
      for (final row in rows)
        row['id'] as String: UserProfile(
          id: row['id'] as String,
          email: row['email'] as String,
          displayName: row['display_name'] as String?,
          avatarUrl: row['avatar_url'] as String?,
        ),
    };
  }
}
