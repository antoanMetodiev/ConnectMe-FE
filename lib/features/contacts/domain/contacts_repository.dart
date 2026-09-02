import 'contact_models.dart';

abstract class ContactsRepository {
  Future<List<ContactSearchResult>> searchUsers(String query);

  /// Any registered user matching [query] by name/email — unlike
  /// [searchUsers], not scoped to contacts. Used for picking group-call
  /// participants, who don't have to be contacts.
  Future<List<UserProfile>> searchAnyUser(String query);

  /// Pending contact requests sent *to* the current user.
  Future<List<ContactSearchResult>> incomingRequests();

  /// Contacts whose request has been mutually accepted.
  Future<List<UserProfile>> acceptedContacts();

  /// Requests *we* sent that the other side has since accepted or declined.
  Future<List<ContactActivity>> sentRequestActivity();

  Future<void> sendRequest(String userId);

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  });
}
