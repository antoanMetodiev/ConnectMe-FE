import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../contacts/domain/contact_models.dart';
import '../data/supabase_groups_repository.dart';
import '../domain/group_models.dart';
import '../domain/groups_repository.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return SupabaseGroupsRepository(supabase.Supabase.instance.client);
});

final groupListProvider = StreamProvider.autoDispose<List<GroupSummary>>((
  ref,
) {
  return ref.read(groupsRepositoryProvider).watchGroups();
});

const groupMessagePageSize = 20;

/// How many messages are currently loaded for a group — starts at one page
/// and grows as the user scrolls further into history.
final groupMessageLimitProvider = StateProvider.autoDispose.family<int, String>(
  (ref, groupId) => groupMessagePageSize,
);

final groupMessagesProvider = StreamProvider.autoDispose
    .family<List<GroupMessage>, String>((ref, groupId) {
      final limit = ref.watch(groupMessageLimitProvider(groupId));
      return ref
          .read(groupsRepositoryProvider)
          .watchGroupMessages(groupId, limit: limit);
    });

final groupProvider = FutureProvider.autoDispose.family<GroupSummary, String>(
  (ref, groupId) {
    return ref.read(groupsRepositoryProvider).getGroup(groupId);
  },
);

final groupMembersProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, groupId) {
      return ref.read(groupsRepositoryProvider).groupMembers(groupId);
    });
