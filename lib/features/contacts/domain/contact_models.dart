enum ContactStatus { none, pendingSent, pendingReceived, accepted }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;

  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : email;
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class ContactSearchResult {
  const ContactSearchResult({
    required this.profile,
    required this.status,
    this.requestId,
  });

  final UserProfile profile;
  final ContactStatus status;

  /// Id of the pending/accepted contact_requests row, when one exists —
  /// needed to accept/decline a received request.
  final String? requestId;
}

class ContactsFailure implements Exception {
  const ContactsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
