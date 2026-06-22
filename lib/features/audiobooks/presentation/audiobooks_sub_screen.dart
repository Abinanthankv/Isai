import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as p;
import '../../music/presentation/music_providers.dart';
import 'audiobook_providers.dart';
import '../data/audiobook_models.dart';
import 'audiobook_detail_screen.dart';
import 'audiobook_now_playing_screen.dart';
import 'package:isai/main.dart'; // For audioHandler

class AudiobooksSubScreen extends ConsumerStatefulWidget {
  const AudiobooksSubScreen({super.key});

  @override
  ConsumerState<AudiobooksSubScreen> createState() => _AudiobooksSubScreenState();
}

class _AudiobooksSubScreenState extends ConsumerState<AudiobooksSubScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _libraryTab = 'local';

  static const List<String> _genres = [
    'All',
    'Fiction',
    'Fantasy',
    'Sci-Fi',
    'Biography',
    'History',
    'Mystery',
    'Business',
    'Self-Help',
    'Classics',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _resumePlayback(BuildContext context, WidgetRef ref, AudiobookResult book) async {
    final repo = ref.read(audiobookRepositoryProvider);
    
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final progress = await repo.getLatestBookProgress(book.id);
      final chapters = await repo.getBookChapters(book.id);
      
      if (context.mounted) Navigator.pop(context); // Dismiss loading dialog
      
      if (chapters.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No chapters found to play.')),
          );
        }
        return;
      }
      
      final chapterIdx = (progress != null && progress.chapterIndex < chapters.length) 
          ? progress.chapterIndex 
          : 0;
      final chapter = chapters[chapterIdx];
      
      final streamUrl = await repo.resolveChapterStream(chapter);
      if (streamUrl == null || streamUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to resolve stream URL.')),
          );
        }
        return;
      }
      
      // Cache metadata on resume
      await repo.cacheBookMetadata(book);

      // Play via AudioHandler
      await audioHandler.customAction('play', {
        'url': streamUrl,
        'title': chapter.title,
        'artist': book.author,
        'artworkUrl': book.artworkUrl ?? '',
        'forceReplace': true,
        'mediaType': 'audiobook', // critical guard
        'extras': {
          'bookId': book.id,
          'chapterIndex': chapterIdx,
          'initialPositionMillis': progress?.positionMillis ?? 0,
        },
      });
      
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookNowPlayingScreen(book: book)),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Dismiss loading dialog if error
      print('[AudiobooksSubScreen] Resume playback error: $e');
    }
  }

  void _showProgressOptions(BuildContext context, WidgetRef ref, AudiobookWithProgress progress) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Show Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudiobookDetailScreen(book: progress.book),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove from Continue Listening', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final repo = ref.read(audiobookRepositoryProvider);
                  await repo.clearBookProgress(progress.book.id);
                  ref.invalidate(inProgressAudiobooksProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed book progress.')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocalBookOptions(BuildContext context, WidgetRef ref, AudiobookResult book) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Show Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AudiobookDetailScreen(book: book),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Fetch Online Metadata'),
                onTap: () {
                  Navigator.pop(context);
                  _showMetadataSearchSheet(context, ref, book);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMetadataSearchSheet(BuildContext context, WidgetRef ref, AudiobookResult currentBook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return MetadataSearchWidget(
              currentBook: currentBook,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(audiobookSearchProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(audiobookSearchProvider);
    final catalogAsync = ref.watch(audiobookCatalogProvider);
    final inProgressAsync = ref.watch(inProgressAudiobooksProvider);
    final localAudiobooksAsync = ref.watch(localAudiobooksProvider);

    return CustomScrollView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search audiobooks...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(audiobookSearchProvider.notifier).clear();
                    },
                  )
              ],
              onChanged: _onSearchChanged,
            ),
          ),
        ),

        // Content
        if (searchState.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (searchState.results.isNotEmpty)
          // Search Results
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final book = searchState.results[index];
                  return _buildListTile(context, book);
                },
                childCount: searchState.results.length,
              ),
            ),
          )
        else if (searchState.query.isNotEmpty && !searchState.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No results found.')),
            ),
          )
        else ...[
          // Default Content
          
          // Continue Listening (if any)
          inProgressAsync.when(
            data: (progressList) {
              if (progressList.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Continue Listening',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: progressList.length,
                        itemBuilder: (context, index) {
                          final progress = progressList[index];
                          return _buildProgressCard(context, progress);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // In Library (local audiobooks)
          localAudiobooksAsync.when(
            data: (allBooks) {
              if (allBooks.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              final localBooksList = allBooks.where((book) => book.id.startsWith('local:')).toList();
              final torBoxBooksList = allBooks.where((book) => book.id.startsWith('torrent:')).toList();

              final displayBooks = _libraryTab == 'local' ? localBooksList : torBoxBooksList;

              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'In Library',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'local',
                                label: Text('Local'),
                                icon: Icon(Icons.phone_android_rounded, size: 16),
                              ),
                              ButtonSegment<String>(
                                value: 'torbox',
                                label: Text('TorBox'),
                                icon: Icon(Icons.cloud_queue_rounded, size: 16),
                              ),
                            ],
                            selected: {_libraryTab},
                            onSelectionChanged: (newSelection) {
                              setState(() {
                                _libraryTab = newSelection.first;
                              });
                            },
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (displayBooks.isEmpty)
                      Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: Text(
                          _libraryTab == 'local'
                              ? 'No downloaded or local books.'
                              : 'No books in TorBox cloud library.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: displayBooks.length,
                          itemBuilder: (context, index) {
                            final book = displayBooks[index];
                            return _buildLocalBookCard(context, book);
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // Browse Catalog Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Browse Audiobooks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  catalogAsync.when(
                    data: (catalog) {
                      if (catalog.length <= 10) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AudiobookCatalogAllScreen(catalog: catalog),
                            ),
                          );
                        },
                        child: const Text('See More'),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          // Genre Filter Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _genres.length,
                itemBuilder: (context, index) {
                  final genre = _genres[index];
                  final selectedGenre = ref.watch(selectedGenreProvider);
                  final isSelected = selectedGenre == genre;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(genre),
                      selected: isSelected,
                      onSelected: (selected) {
                        print('[AudiobooksSubScreen] Genre selected: $genre, status: $selected');
                        if (selected) {
                          ref.read(selectedGenreProvider.notifier).state = genre;
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          
          catalogAsync.when(
            skipLoadingOnReload: true,
            data: (catalog) {
              if (catalog.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('Catalog empty or failed to load.')),
                );
              }
              final displayCount = catalog.length > 10 ? 10 : catalog.length;
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = catalog[index];
                      return _buildGridCard(context, book);
                    },
                    childCount: displayCount,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, st) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListTile(BuildContext context, AudiobookResult book) {
    final isTorrent = book.id.startsWith('torrent:');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: _buildArtworkWidget(
        book.artworkUrl,
        width: 60,
        height: 60,
        borderRadius: 8,
        isTorrent: isTorrent,
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (isTorrent) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'TORRENT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
          Expanded(
            child: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
        );
      },
    );
  }

  Widget _buildArtworkWidget(String? url, {double? width, double? height, double borderRadius = 12, bool isTorrent = false}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(
          isTorrent ? Icons.download_for_offline_rounded : Icons.book,
          size: (width != null && width.isFinite) ? width * 0.5 : 28,
        ),
      );
    }

    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final cleanPath = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isLocal
          ? Image.file(
              File(cleanPath),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  isTorrent ? Icons.download_for_offline_rounded : Icons.book,
                  size: (width != null && width.isFinite) ? width * 0.5 : 28,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, url, error) => Container(
                width: width,
                height: height,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  isTorrent ? Icons.download_for_offline_rounded : Icons.book,
                  size: (width != null && width.isFinite) ? width * 0.5 : 28,
                ),
              ),
            ),
    );
  }

  Widget _buildGridCard(BuildContext context, AudiobookResult book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
        );
      },
      onLongPress: () => _showLocalBookOptions(context, ref, book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildArtworkWidget(
              book.artworkUrl,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalBookCard(BuildContext context, AudiobookResult book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
        );
      },
      onLongPress: () => _showLocalBookOptions(context, ref, book),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: book.artworkUrl != null
                  ? _buildArtworkWidget(
                      book.artworkUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 12,
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_music_rounded,
                            size: 40,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${book.totalChapters ?? 0} files',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, AudiobookWithProgress progress) {
    return GestureDetector(
      onTap: () => _resumePlayback(context, ref, progress.book),
      onLongPress: () => _showProgressOptions(context, ref, progress),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildArtworkWidget(
                progress.book.artworkUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.progressPercent,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }
}

class AudiobookCatalogAllScreen extends StatelessWidget {
  final List<AudiobookResult> catalog;

  const AudiobookCatalogAllScreen({super.key, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Audiobooks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: catalog.length,
          itemBuilder: (context, index) {
            final book = catalog[index];
            return _buildGridCardForAllScreen(context, book);
          },
        ),
      ),
    );
  }

  Widget _buildGridCardForAllScreen(BuildContext context, AudiobookResult book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: book.artworkUrl != null && book.artworkUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: book.artworkUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.book, size: 40),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 40),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
