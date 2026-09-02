import '../../contacts/domain/contact_models.dart';
import 'group_models.dart';

abstract class GroupsRepository {
  /// Creates a group with the current user plus [memberIds] as members.
  /// Returns the new group's id.
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  });

  /// Groups the current user is part of, newest activity first — live,
  /// same as [ChatRepository.watchChats].
  Stream<List<GroupSummary>> watchGroups();

  /// A single group's own record — name and member ids — independent of
  /// the (possibly stale/not-yet-loaded) list from [watchGroups].
  Future<GroupSummary> getGroup(String groupId);

  Future<List<UserProfile>> groupMembers(String groupId);

  /// Live-updating window of the [limit] most recent messages, newest
  /// first. Raise [limit] to page further back into history.
  Stream<List<GroupMessage>> watchGroupMessages(
    String groupId, {
    required int limit,
  });

  Future<void> sendGroupMessage({required String groupId, required String body});
}
