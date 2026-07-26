import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/eclipse_api_service.dart';
import 'music_providers.dart';

final eclipsePlaylistsProvider = FutureProvider<List<EclipsePlaylist>>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (!settings.eclipseIsValid || settings.eclipseToken.isEmpty || settings.eclipseUserId == null) {
    return [];
  }
  final api = EclipseApiService();
  return api.getPlaylists(settings.eclipseToken, settings.eclipseUserId!);
});
