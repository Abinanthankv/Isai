import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/di/injection.dart';
import '../data/audiobook_recommendation_engine.dart';
import '../data/audiobook_repository.dart';
import 'audiobook_providers.dart';

/// Provider for the recommendation engine singleton.
final audiobookRecommendationEngineProvider = Provider<AudiobookRecommendationEngine>((ref) {
  final repo = ref.read(audiobookRepositoryProvider);
  return AudiobookRecommendationEngine(repo, null);
});

/// The user's audiobook listening profile computed from history.
final audiobookUserProfileProvider = FutureProvider<UserAudiobookProfile>((ref) async {
  final engine = ref.read(audiobookRecommendationEngineProvider);
  final repo = ref.read(audiobookRepositoryProvider);

  final history = await repo.getAllProgress();
  final wishlist = ref.watch(audiobookWishlistProvider).value ?? [];
  final wishlistIds = wishlist.map((w) => w.bookId).toSet();

  return engine.buildProfile(history: history, wishlistBookIds: wishlistIds);
});

/// Personalized audiobook recommendations.
final audiobookRecommendationsProvider = FutureProvider<List<AudiobookRecommendation>>((ref) async {
  final engine = ref.read(audiobookRecommendationEngineProvider);
  final profile = await ref.watch(audiobookUserProfileProvider.future);

  if (profile.uniqueBooksCount == 0) {
    return engine.coldStartRecommendations();
  }

  return engine.getRecommendations(profile);
});
