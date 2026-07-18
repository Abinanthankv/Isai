import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom CacheManager for discovery screen images.
/// Limits concurrent downloads to avoid saturating the network.
class DiscoveryCacheManager extends CacheManager {
  static const String key = 'discovery_images';

  static DiscoveryCacheManager? _instance;

  factory DiscoveryCacheManager() {
    _instance ??= DiscoveryCacheManager._();
    return _instance!;
  }

  DiscoveryCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 200,
            fileService: _service,
          ),
        );

  static final FileService _service = HttpFileService()
    ..concurrentFetches = 6;
}
