import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/contact_activity_prefs.dart';
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
    ref.invalidate(incomingRequestsControllerProvider);
    await search(_lastQuery);
  }
}

final contactsSearchControllerProvider =
    AsyncNotifierProvider<
      ContactsSearchController,
      List<ContactSearchResult>
    >(ContactsSearchController.new);

class IncomingRequestsController
    extends AsyncNotifier<List<ContactSearchResult>> {
  @override
  FutureOr<List<ContactSearchResult>> build() =>
      ref.read(contactsRepositoryProvider).incomingRequests();

  Future<void> respond({
    required String requestId,
    required bool accept,
  }) async {
    await ref
        .read(contactsRepositoryProvider)
        .respondToRequest(requestId: requestId, accept: accept);
    ref.invalidateSelf();
    await future;
  }
}

final incomingRequestsControllerProvider =
    AsyncNotifierProvider<
      IncomingRequestsController,
      List<ContactSearchResult>
    >(IncomingRequestsController.new);

/// Count of pending incoming requests, for the badge on the new-chat FAB.
final pendingRequestsCountProvider = FutureProvider<int>((ref) async {
  final requests = await ref.watch(incomingRequestsControllerProvider.future);
  return requests.length;
});

final acceptedContactsProvider = FutureProvider<List<UserProfile>>((ref) {
  return ref.read(contactsRepositoryProvider).acceptedContacts();
});

class ContactActivityController extends AsyncNotifier<List<ContactActivity>> {
  @override
  FutureOr<List<ContactActivity>> build() async {
    final activity = await ref
        .read(contactsRepositoryProvider)
        .sentRequestActivity();
    final seen = await ContactActivityPrefs.seenRequestIds();
    // Already-seen entries were shown once and don't come back — this is
    // what makes them "disappear" from the list after being read.
    return activity.where((a) => !seen.contains(a.requestId)).toList();
  }

  /// Marks every entry currently loaded as seen, so it won't reappear next
  /// time this list is fetched. Call when leaving the screen, not on open —
  /// removing entries while the user is still looking at them would be
  /// jarring.
  Future<void> markLoadedAsSeen() async {
    final activity = state.value;
    if (activity == null || activity.isEmpty) return;
    await ContactActivityPrefs.markSeen(activity.map((a) => a.requestId));
  }
}

final contactActivityControllerProvider =
    AsyncNotifierProvider<ContactActivityController, List<ContactActivity>>(
      ContactActivityController.new,
    );

/// Count of accept/decline responses not yet shown in the activity list,
/// for the notifications-bell badge.
final unseenContactActivityCountProvider = FutureProvider<int>((ref) async {
  final activity = await ref.watch(contactActivityControllerProvider.future);
  return activity.length;
});
