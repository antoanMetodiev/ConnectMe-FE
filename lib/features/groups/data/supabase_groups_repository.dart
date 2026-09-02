import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../contacts/domain/contact_models.dart';
import '../domain/group_models.dart';
import '../domain/groups_repository.dart';

class SupabaseGroupsRepository implements GroupsRepository {
  SupabaseGroupsRepository(this._client);

  final supabase.SupabaseClient _client;

  String get _myId => _client.auth.currentUser!.id;

  @override
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const GroupFailure('Името на групата не може да е празно.');
    }
    // Generated client-side and inserted without asking PostgREST to hand
    // the row back — under RLS, a SELECT-back on the insert would need the
    // creator to already be a group_members row, which doesn't exist until
    // the very next statement below.
    final groupId = const Uuid().v4();
    try {
      await _client.from('groups').insert({
        'id': groupId,
        'name': trimmedName,
        'created_by': _myId,
      });

      final memberRows = {_myId, ...memberIds}
          .map((id) => {'group_id': groupId, 'user_id': id})
          .toList();
      await _client.from('group_members').insert(memberRows);

      return groupId;
    } on supabase.PostgrestException catch (e) {
      throw GroupFailure(e.message);
    }
  }

  Future<List<GroupSummary>> _listGroups() async {
    final memberRows = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', _myId);
    final groupIds = memberRows
        .map((r) => r['group_id'] as String)
        .toSet()
        .toList();
    if (groupIds.isEmpty) return [];

    final groupRows = await _client
        .from('groups')
        .select()
        .inFilter('id', groupIds);

    final allMemberRows = await _client
        .from('group_members')
        .select()
        .inFilter('group_id', groupIds);
    final memberIdsByGroup = <String, List<String>>{};
    for (final row in allMemberRows) {
      memberIdsByGroup
          .putIfAbsent(row['group_id'] as String, () => [])
          .add(row['user_id'] as String);
    }

    final messageRows = await _client
        .from('group_messages')
        .select()
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false);
    final latestByGroup = <String, Map<String, dynamic>>{};
    for (final row in messageRows) {
      latestByGroup.putIfAbsent(row['group_id'] as String, () => row);
    }

    final summaries = groupRows.map((row) {
      final id = row['id'] as String;
      final lastMessage = latestByGroup[id];
      return GroupSummary(
        id: id,
        name: row['name'] as String,
        memberIds: memberIdsByGroup[id] ?? const [],
        lastMessageBody: lastMessage?['body'] as String?,
        lastMessageSenderId: lastMessage?['sender_id'] as String?,
        lastMessageAt: lastMessage != null
            ? DateTime.parse(lastMessage['created_at'] as String)
            : DateTime.parse(row['created_at'] as String),
      );
    }).toList();

    summaries.sort((a, b) {
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return summaries;
  }

  @override
  Stream<List<GroupSummary>> watchGroups() async* {
    yield await _listGroups();
    // Same trick as watchChats(): re-run the aggregate query on every
    // message change visible to this user (RLS scopes it to their own
    // groups), so previews and ordering stay live.
    await for (final _ in _client
        .from('group_messages')
        .stream(primaryKey: ['id'])) {
      yield await _listGroups();
    }
  }

  @override
  Future<GroupSummary> getGroup(String groupId) async {
    final row = await _client.from('groups').select().eq('id', groupId).single();
    final memberRows = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    return GroupSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      memberIds: memberRows.map((r) => r['user_id'] as String).toList(),
    );
  }

  @override
  Future<List<UserProfile>> groupMembers(String groupId) async {
    final memberRows = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    final ids = memberRows.map((r) => r['user_id'] as String).toList();
    final profilesById = await _profilesById(ids);
    return profilesById.values.toList();
  }

  @override
  Stream<List<GroupMessage>> watchGroupMessages(
    String groupId, {
    required int limit,
  }) {
    return _client
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map(
                (r) => GroupMessage(
                  id: r['id'] as String,
                  groupId: r['group_id'] as String,
                  senderId: r['sender_id'] as String,
                  body: r['body'] as String,
                  createdAt: DateTime.parse(r['created_at'] as String),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> sendGroupMessage({
    required String groupId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    try {
      await _client.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': _myId,
        'body': trimmed,
      });
    } on supabase.PostgrestException catch (e) {
      throw GroupFailure(e.message);
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
