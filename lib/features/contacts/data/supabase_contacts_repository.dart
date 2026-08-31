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
