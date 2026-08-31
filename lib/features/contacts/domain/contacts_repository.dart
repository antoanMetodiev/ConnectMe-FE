import 'contact_models.dart';

abstract class ContactsRepository {
  Future<List<ContactSearchResult>> searchUsers(String query);

  Future<void> sendRequest(String userId);

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  });
}
