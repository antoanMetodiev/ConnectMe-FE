import '../../contacts/domain/contact_models.dart';

enum StoryMediaType { image, video }

class Story {
  const Story({
    required this.id,
    required this.userId,
    required this.mediaPath,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
    required this.likeCount,
    required this.likedByMe,
    required this.viewCount,
    required this.viewedByMe,
  });

  final String id;
  final String userId;
  final String mediaPath;
  final StoryMediaType mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int likeCount;
  final bool likedByMe;

  /// Only populated for stories the caller owns — RLS hides the viewer
  /// list of anyone else's story, so this is 0 for stories you don't own.
  final int viewCount;

  /// Whether the caller has already opened this specific story — drives
  /// the "seen" (muted) vs. "unseen" (highlighted) ring in the story list.
  final bool viewedByMe;
}

class StoryViewer {
  const StoryViewer({required this.profile, required this.viewedAt});

  final UserProfile profile;
  final DateTime viewedAt;
}

/// One author's still-active stories, oldest first — the unit the viewer
/// pages through segment by segment.
class StoryGroup {
  const StoryGroup({required this.author, required this.stories});

  final UserProfile author;
  final List<Story> stories;

  bool get allSeenByMe => stories.every((s) => s.viewedByMe);
}

class StoriesFailure implements Exception {
  const StoriesFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
