import 'dart:typed_data';

import 'story_models.dart';

abstract class StoriesRepository {
  Stream<List<StoryGroup>> watchStories();

  Future<void> uploadStory({
    required Uint8List bytes,
    required StoryMediaType mediaType,
    required String extension,
    String? contentType,
  });

  Future<void> deleteStory({required String storyId, required String mediaPath});

  /// Best-effort cleanup of the caller's own expired stories — safe to call
  /// whenever the Stories tab is opened.
  Future<void> deleteExpiredMine();

  Future<String> mediaUrl(String storagePath);

  Future<void> setLiked({required String storyId, required bool liked});

  /// Best-effort — records that the caller opened this story. Safe to call
  /// repeatedly (duplicate views are ignored).
  Future<void> markViewed(String storyId);

  /// Full viewer list for a story the caller owns, most recent first.
  Future<List<StoryViewer>> viewers(String storyId);
}
