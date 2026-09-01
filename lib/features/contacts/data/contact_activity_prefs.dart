import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which sent-request responses (accepted/declined) the user has
/// already seen, so the activity badge only counts new ones.
class ContactActivityPrefs {
  ContactActivityPrefs._();

  static const _key = 'seen_contact_activity_request_ids';

  static Future<Set<String>> seenRequestIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  static Future<void> markSeen(Iterable<String> requestIds) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? const []).toSet();
    current.addAll(requestIds);
    await prefs.setStringList(_key, current.toList());
  }
}
