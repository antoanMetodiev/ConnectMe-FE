import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../contacts/domain/contact_models.dart';
import '../domain/stories_repository.dart';
import '../domain/story_models.dart';

const _storiesBucket = 'stories';

class SupabaseStoriesRepository implements StoriesRepository {
  SupabaseStoriesRepository(this._client);

  final supabase.SupabaseClient _client;

  String get _myId => _client.auth.currentUser!.id;

  Future<List<StoryGroup>> _listStoryGroups() async {
    final rows = await _client.from('stories').select().order('created_at');
    if (rows.isEmpty) return [];

    final storyIds = rows.map((r) => r['id'] as String).toList();
    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
    final profilesById = await _profilesById(userIds);

    final likeRows = await _client
        .from('story_likes')
        .select()
        .inFilter('story_id', storyIds);
    final likeCounts = <String, int>{};
    final likedByMe = <String>{};
    for (final row in likeRows) {
      final storyId = row['story_id'] as String;
      likeCounts[storyId] = (likeCounts[storyId] ?? 0) + 1;
      if (row['user_id'] == _myId) likedByMe.add(storyId);
    }

    // RLS only lets a broad `select()` return view rows the caller is
    // allowed to see: their own stories' full viewer lists, plus their own
    // view of anyone else's story — exactly the two things needed here.
    final viewRows = await _client
        .from('story_views')
        .select()
        .inFilter('story_id', storyIds);
    final viewCounts = <String, int>{};
    final viewedByMe = <String>{};
    for (final row in viewRows) {
      final storyId = row['story_id'] as String;
      viewCounts[storyId] = (viewCounts[storyId] ?? 0) + 1;
      if (row['viewer_id'] == _myId) viewedByMe.add(storyId);
    }

    final storiesByUser = <String, List<Story>>{};
    for (final row in rows) {
      final id = row['id'] as String;
      final story = Story(
        id: id,
        userId: row['user_id'] as String,
        mediaPath: row['media_path'] as String,
        mediaType: row['media_type'] == 'video'
            ? StoryMediaType.video
            : StoryMediaType.image,
        createdAt: DateTime.parse(row['created_at'] as String),
        expiresAt: DateTime.parse(row['expires_at'] as String),
        likeCount: likeCounts[id] ?? 0,
        likedByMe: likedByMe.contains(id),
        viewCount: viewCounts[id] ?? 0,
        viewedByMe: viewedByMe.contains(id),
      );
      storiesByUser.putIfAbsent(story.userId, () => []).add(story);
    }

    final groups = storiesByUser.entries
        .map((entry) {
          final author = profilesById[entry.key];
          if (author == null) return null;
          return StoryGroup(author: author, stories: entry.value);
        })
        .whereType<StoryGroup>()
        .toList();

    // Own stories first (so you always see your own row), then contacts
    // most-recently-active first.
    groups.sort((a, b) {
      if (a.author.id == _myId) return -1;
      if (b.author.id == _myId) return 1;
      return b.stories.last.createdAt.compareTo(a.stories.last.createdAt);
    });
    return groups;
  }

  @override
  Stream<List<StoryGroup>> watchStories() async* {
    yield await _listStoryGroups();
    // Same trick as watchChats()/watchGroups(): re-run the aggregate query
    // on every change visible to this user (RLS scopes it to their own +
    // contacts' active stories).
    await for (final _ in _client.from('stories').stream(primaryKey: ['id'])) {
      yield await _listStoryGroups();
    }
  }

  @override
  Future<void> uploadStory({
    required Uint8List bytes,
    required StoryMediaType mediaType,
    required String extension,
    String? contentType,
  }) async {
    final path = '$_myId/${const Uuid().v4()}.$extension';
    try {
      await _client.storage
          .from(_storiesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: supabase.FileOptions(contentType: contentType),
          );
      await _client.from('stories').insert({
        'user_id': _myId,
        'media_path': path,
        'media_type': mediaType == StoryMediaType.video ? 'video' : 'image',
      });
    } on supabase.StorageException catch (e) {
      throw StoriesFailure(e.message);
    } on supabase.PostgrestException catch (e) {
      throw StoriesFailure(e.message);
    }
  }

  @override
  Future<void> deleteStory({
    required String storyId,
    required String mediaPath,
  }) async {
    try {
      await _client.from('stories').delete().eq('id', storyId);
    } on supabase.PostgrestException catch (e) {
      throw StoriesFailure(e.message);
    }
    try {
      await _client.storage.from(_storiesBucket).remove([mediaPath]);
    } catch (_) {
      // Best-effort — the row is already gone, which is what makes the
      // story itself disappear; a lingering object is harmless.
    }
  }

  @override
  Future<void> deleteExpiredMine() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final expired = await _client
        .from('stories')
        .select()
        .eq('user_id', _myId)
        .lt('expires_at', nowIso);
    if (expired.isEmpty) return;

    final paths = expired.map((r) => r['media_path'] as String).toList();
    try {
      await _client.from('stories').delete().eq('user_id', _myId).lt(
        'expires_at',
        nowIso,
      );
    } on supabase.PostgrestException {
      return;
    }
    try {
      await _client.storage.from(_storiesBucket).remove(paths);
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<String> mediaUrl(String storagePath) async {
    try {
      return await _client.storage
          .from(_storiesBucket)
          .createSignedUrl(storagePath, 60 * 60);
    } on supabase.StorageException catch (e) {
      throw StoriesFailure(e.message);
    }
  }

  @override
  Future<void> setLiked({required String storyId, required bool liked}) async {
    try {
      if (liked) {
        await _client.from('story_likes').insert({
          'story_id': storyId,
          'user_id': _myId,
        });
      } else {
        await _client
            .from('story_likes')
            .delete()
            .eq('story_id', storyId)
            .eq('user_id', _myId);
      }
    } on supabase.PostgrestException catch (e) {
      // Already-liked race (unique PK violation) is fine — end state
      // matches intent, nothing to surface to the user.
      if (e.code != '23505') throw StoriesFailure(e.message);
    }
  }

  @override
  Future<void> markViewed(String storyId) async {
    try {
      await _client.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': _myId,
      });
    } catch (_) {
      // Best-effort telemetry — a duplicate view (already marked) or a
      // network hiccup shouldn't interrupt viewing the story.
    }
  }

  @override
  Future<List<StoryViewer>> viewers(String storyId) async {
    final rows = await _client
        .from('story_views')
        .select()
        .eq('story_id', storyId)
        .order('viewed_at', ascending: false);
    if (rows.isEmpty) return [];

    final profilesById = await _profilesById(
      rows.map((r) => r['viewer_id'] as String).toList(),
    );
    return rows
        .map((row) {
          final profile = profilesById[row['viewer_id']];
          if (profile == null) return null;
          return StoryViewer(
            profile: profile,
            viewedAt: DateTime.parse(row['viewed_at'] as String),
          );
        })
        .whereType<StoryViewer>()
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
          avatarUrl: row['avatar_url'] as String?,
        ),
    };
  }
}
