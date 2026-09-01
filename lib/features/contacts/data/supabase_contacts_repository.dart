import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../domain/contact_models.dart';
import '../domain/contacts_repository.dart';

class SupabaseContactsRepository implements ContactsRepository {
  SupabaseContactsRepository(this._client);

  final supabase.SupabaseClient _client;

  String get _myId => _client.auth.currentUser!.id;

  @override
  Future<List<ContactSearchResult>> searchUsers(String query) async {
    // Strip characters that have special meaning in PostgREST's filter
    // syntax so a search term can't alter the query we send.
    final sanitized = query.replaceAll(RegExp(r'[,()]'), '').trim();
    if (sanitized.isEmpty) return [];

    final profileRows = await _client
        .from('profiles')
        .select()
        .neq('id', _myId)
        .or('display_name.ilike.%$sanitized%,email.ilike.%$sanitized%')
        .limit(20);

    final profiles = profileRows
        .map(
          (row) => UserProfile(
            id: row['id'] as String,
            email: row['email'] as String,
            displayName: row['display_name'] as String?,
          ),
        )
        .toList();

    if (profiles.isEmpty) return [];

    final requestRows = await _client
        .from('contact_requests')
        .select()
        .or('requester_id.eq.$_myId,addressee_id.eq.$_myId');

    return profiles.map((profile) {
      final match = requestRows.where(
        (r) =>
            r['requester_id'] == profile.id || r['addressee_id'] == profile.id,
      );
      if (match.isEmpty) {
        return ContactSearchResult(
          profile: profile,
          status: ContactStatus.none,
        );
      }

      final row = match.first;
      final status = row['status'] as String;
      final requestId = row['id'] as String;

      if (status == 'accepted') {
        return ContactSearchResult(
          profile: profile,
          status: ContactStatus.accepted,
          requestId: requestId,
        );
      }
      if (status == 'declined') {
        return ContactSearchResult(
          profile: profile,
          status: ContactStatus.none,
        );
      }
      final iAmRequester = row['requester_id'] == _myId;
      return ContactSearchResult(
        profile: profile,
        status: iAmRequester
            ? ContactStatus.pendingSent
            : ContactStatus.pendingReceived,
        requestId: requestId,
      );
    }).toList();
  }

  @override
  Future<List<ContactSearchResult>> incomingRequests() async {
    final requestRows = await _client
        .from('contact_requests')
        .select()
        .eq('addressee_id', _myId)
        .eq('status', 'pending');

    if (requestRows.isEmpty) return [];

    final profilesById = await _profilesById(
      requestRows.map((r) => r['requester_id'] as String).toList(),
    );

    return requestRows
        .map((r) {
          final profile = profilesById[r['requester_id']];
          if (profile == null) return null;
          return ContactSearchResult(
            profile: profile,
            status: ContactStatus.pendingReceived,
            requestId: r['id'] as String,
          );
        })
        .whereType<ContactSearchResult>()
        .toList();
  }

  @override
  Future<List<UserProfile>> acceptedContacts() async {
    final rows = await _client
        .from('contact_requests')
        .select()
        .eq('status', 'accepted')
        .or('requester_id.eq.$_myId,addressee_id.eq.$_myId');

    if (rows.isEmpty) return [];

    final otherIds = rows
        .map(
          (r) => r['requester_id'] == _myId
              ? r['addressee_id'] as String
              : r['requester_id'] as String,
        )
        .toList();

    final profilesById = await _profilesById(otherIds);
    final contacts = profilesById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return contacts;
  }

  @override
  Future<List<ContactActivity>> sentRequestActivity() async {
    final rows = await _client
        .from('contact_requests')
        .select()
        .eq('requester_id', _myId)
        .inFilter('status', ['accepted', 'declined'])
        .order('updated_at', ascending: false);

    if (rows.isEmpty) return [];

    final profilesById = await _profilesById(
      rows.map((r) => r['addressee_id'] as String).toList(),
    );

    return rows
        .map((r) {
          final profile = profilesById[r['addressee_id']];
          if (profile == null) return null;
          return ContactActivity(
            requestId: r['id'] as String,
            profile: profile,
            accepted: r['status'] == 'accepted',
          );
        })
        .whereType<ContactActivity>()
        .toList();
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
        ),
    };
  }

  @override
  Future<void> sendRequest(String userId) async {
    try {
      await _client.from('contact_requests').insert({
        'requester_id': _myId,
        'addressee_id': userId,
      });
    } on supabase.PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ContactsFailure('Вече има покана между вас.');
      }
      throw ContactsFailure(e.message);
    }
  }

  @override
  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    try {
      await _client
          .from('contact_requests')
          .update({'status': accept ? 'accepted' : 'declined'})
          .eq('id', requestId);
    } on supabase.PostgrestException catch (e) {
      throw ContactsFailure(e.message);
    }
  }
}
