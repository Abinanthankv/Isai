import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/di/injection.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/apple_music_theme.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/apple_music_components.dart';
import '../../music/presentation/music_providers.dart';

// Slider discrete values for Song Cache
const List<int> songCacheLimitSteps = [512, 1024, 2048, 5120, 10240, -1]; // -1 represents Unlimited
const List<String> songCacheLimitLabels = ['512 MB', '1 GB', '2 GB', '5 GB', '10 GB', 'Unlimited'];

// Slider discrete values for Image Cache
const List<int> imageCacheLimitSteps = [128, 256, 512, 1024, 2048, -1]; // -1 represents Unlimited
const List<String> imageCacheLimitLabels = ['128 MB', '256 MB', '512 MB', '1 GB', '2 GB', 'Unlimited'];

class StorageSettingsState {
  final int downloadedSongsSize;
  final int songCacheSize;
  final int imageCacheSize;
  final bool isClearingDownloads;
  final bool isClearingSongCache;
  final bool isClearingImageCache;

  StorageSettingsState({
    this.downloadedSongsSize = 0,
    this.songCacheSize = 0,
    this.imageCacheSize = 0,
    this.isClearingDownloads = false,
    this.isClearingSongCache = false,
    this.isClearingImageCache = false,
  });

  StorageSettingsState copyWith({
    int? downloadedSongsSize,
    int? songCacheSize,
    int? imageCacheSize,
    bool? isClearingDownloads,
    bool? isClearingSongCache,
    bool? isClearingImageCache,
  }) {
    return StorageSettingsState(
      downloadedSongsSize: downloadedSongsSize ?? this.downloadedSongsSize,
      songCacheSize: songCacheSize ?? this.songCacheSize,
      imageCacheSize: imageCacheSize ?? this.imageCacheSize,
      isClearingDownloads: isClearingDownloads ?? this.isClearingDownloads,
      isClearingSongCache: isClearingSongCache ?? this.isClearingSongCache,
      isClearingImageCache: isClearingImageCache ?? this.isClearingImageCache,
    );
  }
}

class StorageSettingsNotifier extends Notifier<StorageSettingsState> {
  late final AppDatabase _db;

  @override
  StorageSettingsState build() {
    _db = getIt<AppDatabase>();
    Future.microtask(() => refreshSizes());
    return StorageSettingsState();
  }

  Future<void> refreshSizes() async {
    final downloaded = await _calcDownloadedSize();
    final songCache = await _calcSongCacheSize();
    final imageCache = await _calcImageCacheSize();

    state = state.copyWith(
      downloadedSongsSize: downloaded,
      songCacheSize: songCache,
      imageCacheSize: imageCache,
    );
  }

  Future<int> _calcDownloadedSize() async {
    try {
      final dbFiles = await _db.getAllFiles();
      int total = 0;
      for (final f in dbFiles) {
        if (f.localPath != null) {
          final file = io.File(f.localPath!);
          if (await file.exists()) {
            total += await file.length();
          }
        }
      }
      return total;
    } catch (e) {
      print('[StorageSettings] Error calculating downloaded size: $e');
      return 0;
    }
  }

  Future<int> _calcSongCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final songCacheDir = io.Directory('${tempDir.path}/audio_cache');
      return await _getDirSize(songCacheDir);
    } catch (e) {
      print('[StorageSettings] Error calculating song cache size: $e');
      return 0;
    }
  }

  Future<int> _calcImageCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final imageCacheDir = io.Directory('${tempDir.path}/libCachedImageData');
      return await _getDirSize(imageCacheDir);
    } catch (e) {
      print('[StorageSettings] Error calculating image cache size: $e');
      return 0;
    }
  }

  Future<int> _getDirSize(io.Directory dir) async {
    int size = 0;
    if (await dir.exists()) {
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is io.File) {
            size += await entity.length();
          }
        }
      } catch (_) {}
    }
    return size;
  }

  Future<void> clearDownloads(WidgetRef ref) async {
    state = state.copyWith(isClearingDownloads: true);
    try {
      final dbFiles = await _db.getAllFiles();
      for (final f in dbFiles) {
        if (f.localPath != null) {
          final file = io.File(f.localPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
      await _db.clearAllLocalPaths();
      // Reload library
      await ref.read(libraryProvider.notifier).loadLibrary(force: true);
      await refreshSizes();
    } catch (e) {
      print('[StorageSettings] Error clearing downloads: $e');
    } finally {
      state = state.copyWith(isClearingDownloads: false);
    }
  }

  Future<void> clearSongCache() async {
    state = state.copyWith(isClearingSongCache: true);
    try {
      final tempDir = await getTemporaryDirectory();
      final songCacheDir = io.Directory('${tempDir.path}/audio_cache');
      if (await songCacheDir.exists()) {
        final entities = songCacheDir.listSync();
        for (final entity in entities) {
          if (entity is io.File) {
            await entity.delete();
          }
        }
      }
      await refreshSizes();
    } catch (e) {
      print('[StorageSettings] Error clearing song cache: $e');
    } finally {
      state = state.copyWith(isClearingSongCache: false);
    }
  }

  Future<void> clearImageCache() async {
    state = state.copyWith(isClearingImageCache: true);
    try {
      await DefaultCacheManager().emptyCache();
      await refreshSizes();
    } catch (e) {
      print('[StorageSettings] Error clearing image cache: $e');
    } finally {
      state = state.copyWith(isClearingImageCache: false);
    }
  }
}

final storageSettingsProvider = NotifierProvider<StorageSettingsNotifier, StorageSettingsState>(() {
  return StorageSettingsNotifier();
});

class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final storageState = ref.watch(storageSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine current index for sliders
    final songLimitIndex = songCacheLimitSteps.indexOf(settings.maxSongCacheSize);
    final currentSongLimitIdx = songLimitIndex != -1 ? songLimitIndex : 1; // Default to 1 GB

    final imageLimitIndex = imageCacheLimitSteps.indexOf(settings.maxImageCacheSize);
    final currentImageLimitIdx = imageLimitIndex != -1 ? imageLimitIndex : 2; // Default to 512 MB

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Colors.black, Color(0xFF120816)]
              : const [Color(0xFFF5F5F7), Color(0xFFF6F0FA)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Storage',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: STORAGE
                    AppleMusicSectionHeader(title: 'Storage'),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _StorageTile(
                            icon: Icons.format_list_bulleted_rounded,
                            title: 'Downloaded songs',
                            subtitle: _formatBytes(storageState.downloadedSongsSize),
                          ),
                          const Divider(height: 1, indent: 56),
                          _ActionTile(
                            icon: Icons.clear_all_rounded,
                            title: 'Clear all downloads',
                            isLoading: storageState.isClearingDownloads,
                            onTap: () => _confirmClear(
                              context,
                              title: 'Clear all downloads?',
                              message: 'This will delete all downloaded song files from this device.',
                              onConfirm: () => ref.read(storageSettingsProvider.notifier).clearDownloads(ref),
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          _ActionTile(
                            icon: Icons.auto_delete_outlined,
                            title: 'Clear library database',
                            isLoading: false,
                            onTap: () => _confirmClear(
                              context,
                              title: 'Clear library database?',
                              message: 'This will delete all synchronized TorBox files and metadata. It will rebuild automatically from the cloud.',
                              onConfirm: () => ref.read(libraryProvider.notifier).clearLibrary(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SECTION 2: SONG CACHE
                    AppleMusicSectionHeader(title: 'Song Cache'),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.cached_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Max song cache size',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,),
                                    ),
                                    Text(
                                      songCacheLimitLabels[currentSongLimitIdx],
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppleMusicTheme.primaryOrange,
                              inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                              thumbColor: AppleMusicTheme.primaryOrange,
                              overlayColor: AppleMusicTheme.primaryOrange.withOpacity(0.2),
                              valueIndicatorColor: AppleMusicTheme.primaryOrange,
                              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                              activeTickMarkColor: AppleMusicTheme.primaryOrange,
                              inactiveTickMarkColor: isDark ? Colors.white24 : Colors.black26,
                            ),
                            child: Slider(
                              value: currentSongLimitIdx.toDouble(),
                              min: 0,
                              max: (songCacheLimitSteps.length - 1).toDouble(),
                              divisions: songCacheLimitSteps.length - 1,
                              onChanged: (val) {
                                final size = songCacheLimitSteps[val.toInt()];
                                ref.read(settingsProvider.notifier).setMaxSongCacheSize(size);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${_formatBytes(storageState.songCacheSize)} / ${songCacheLimitLabels[currentSongLimitIdx]}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _ActionTile(
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear song cache',
                            isLoading: storageState.isClearingSongCache,
                            padding: EdgeInsets.zero,
                            onTap: () => _confirmClear(
                              context,
                              title: 'Clear song cache?',
                              message: 'This will clear temporary song audio files stored on your device to free up space.',
                              onConfirm: () => ref.read(storageSettingsProvider.notifier).clearSongCache(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SECTION 3: IMAGE CACHE
                    AppleMusicSectionHeader(title: 'Image Cache'),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.image_search_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Max image cache size',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black,),
                                    ),
                                    Text(
                                      imageCacheLimitLabels[currentImageLimitIdx],
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppleMusicTheme.primaryOrange,
                              inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                              thumbColor: AppleMusicTheme.primaryOrange,
                              overlayColor: AppleMusicTheme.primaryOrange.withOpacity(0.2),
                              valueIndicatorColor: AppleMusicTheme.primaryOrange,
                              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                              activeTickMarkColor: AppleMusicTheme.primaryOrange,
                              inactiveTickMarkColor: isDark ? Colors.white24 : Colors.black26,
                            ),
                            child: Slider(
                              value: currentImageLimitIdx.toDouble(),
                              min: 0,
                              max: (imageCacheLimitSteps.length - 1).toDouble(),
                              divisions: imageCacheLimitSteps.length - 1,
                              onChanged: (val) {
                                final size = imageCacheLimitSteps[val.toInt()];
                                ref.read(settingsProvider.notifier).setMaxImageCacheSize(size);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${_formatBytes(storageState.imageCacheSize)} / ${imageCacheLimitLabels[currentImageLimitIdx]}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: isDark ? Colors.white38 : Colors.black38,),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _ActionTile(
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear image cache',
                            isLoading: storageState.isClearingImageCache,
                            padding: EdgeInsets.zero,
                            onTap: () => _confirmClear(
                              context,
                              title: 'Clear image cache?',
                              message: 'This will delete cached album art and artist images.',
                              onConfirm: () => ref.read(storageSettingsProvider.notifier).clearImageCache(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: Text(message, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StorageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StorageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white54 : Colors.black45,),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isLoading;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.isLoading,
    required this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,),
                ),
              ),
              if (isLoading)
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
