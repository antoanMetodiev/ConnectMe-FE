class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.memberIds,
    this.lastMessageBody,
    this.lastMessageSenderId,
    this.lastMessageAt,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;

  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

class GroupFailure implements Exception {
  const GroupFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
