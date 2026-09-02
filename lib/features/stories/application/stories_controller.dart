import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../data/supabase_stories_repository.dart';
import '../domain/stories_repository.dart';
import '../domain/story_models.dart';

final storiesRepositoryProvider = Provider<StoriesRepository>((ref) {
  return SupabaseStoriesRepository(supabase.Supabase.instance.client);
});

final storyGroupsProvider = StreamProvider.autoDispose<List<StoryGroup>>((
  ref,
) {
  return ref.watch(storiesRepositoryProvider).watchStories();
});
