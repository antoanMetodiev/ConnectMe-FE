import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/supabase_contacts_repository.dart';
import '../domain/contact_models.dart';
import '../domain/contacts_repository.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return SupabaseContactsRepository(supabase.Supabase.instance.client);
});

class ContactsSearchController
    extends AsyncNotifier<List<ContactSearchResult>> {
  String _lastQuery = '';

  @override
  FutureOr<List<ContactSearchResult>> build() => [];

  Future<void> search(String query) async {
    _lastQuery = query;
    if (query.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(contactsRepositoryProvider).searchUsers(query),
    );
  }

  /// Propagates failures to the caller instead of the notifier's own state,
  /// so a failed action doesn't wipe the results already on screen.
  Future<void> sendRequest(String userId) async {
    await ref.read(contactsRepositoryProvider).sendRequest(userId);
    await search(_lastQuery);
  }

  Future<void> respond({
    required String requestId,
    required bool accept,
  }) async {
    await ref
        .read(contactsRepositoryProvider)
        .respondToRequest(requestId: requestId, accept: accept);
    await search(_lastQuery);
  }
}

final contactsSearchControllerProvider =
    AsyncNotifierProvider<
      ContactsSearchController,
      List<ContactSearchResult>
    >(ContactsSearchController.new);
