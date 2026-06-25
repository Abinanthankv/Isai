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
  final TextEditingController _continueSearchController = TextEditingController();
  Timer? _debounce;
  String _libraryTab = 'local';
  String _librarySort = 'recent'; // recent, author, title, progress

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
    _continueSearchController.dispose();
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
                  await repo.dismissBookFromContinueListening(progress.book.id);
                  ref.invalidate(inProgressAudiobooksProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from Continue Listening.')),
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

              final filteredList = _continueSearchController.text.isEmpty
                  ? progressList
                  : progressList.where((p) =>
                      p.book.title.toLowerCase().contains(_continueSearchController.text.toLowerCase()) ||
                      p.book.author.toLowerCase().contains(_continueSearchController.text.toLowerCase())
                    ).toList();

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
                            'Continue Listening',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (progressList.length > 3)
                            SizedBox(
                              width: 140,
                              height: 32,
                              child: TextField(
                                controller: _continueSearchController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  suffixIcon: _continueSearchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 14),
                                          onPressed: () {
                                            _continueSearchController.clear();
                                            setState(() {});
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (filteredList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('No matches found.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      )
                    else
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final progress = filteredList[index];
                            return _buildProgressCard(context, progress);
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Row(
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Loading continue listening...', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            error: (e, _) {
              print('[AudiobooksSubScreen] Continue Listening error: $e');
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),

          // Wishlist section
          ref.watch(audiobookWishlistProvider).when(
            data: (wishlist) {
              if (wishlist.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Plan to Read (${wishlist.length})',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: wishlist.length,
                        itemBuilder: (context, index) {
                          final item = wishlist[index];
                          final book = AudiobookResult(
                            id: item.bookId,
                            title: item.title,
                            author: item.author,
                            artworkUrl: item.artworkUrl,
                          );
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

          // In Library (local audiobooks)
          localAudiobooksAsync.when(
            data: (allBooks) {
              if (allBooks.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              final localBooksList = allBooks.where((book) => book.id.startsWith('local:')).toList();
              final torBoxBooksList = allBooks.where((book) => book.id.startsWith('torrent:')).toList();

              List<AudiobookResult> displayBooks = _libraryTab == 'local' ? localBooksList : torBoxBooksList;
              switch (_librarySort) {
                case 'author':
                  displayBooks = List.from(displayBooks)..sort((a, b) => a.author.compareTo(b.author));
                  break;
                case 'title':
                  displayBooks = List.from(displayBooks)..sort((a, b) => a.title.compareTo(b.title));
                  break;
                case 'recent':
                default:
                  break;
              }

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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sort dropdown
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.sort_rounded, size: 20),
                                tooltip: 'Sort by',
                                onSelected: (value) => setState(() => _librarySort = value),
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'recent', child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 18, color: _librarySort == 'recent' ? Theme.of(context).colorScheme.primary : null),
                                      const SizedBox(width: 8),
                                      Text('Recently Added', style: TextStyle(fontWeight: _librarySort == 'recent' ? FontWeight.bold : FontWeight.normal)),
                                    ],
                                  )),
                                  PopupMenuItem(value: 'author', child: Row(
                                    children: [
                                      Icon(Icons.person_rounded, size: 18, color: _librarySort == 'author' ? Theme.of(context).colorScheme.primary : null),
                                      const SizedBox(width: 8),
                                      Text('Author', style: TextStyle(fontWeight: _librarySort == 'author' ? FontWeight.bold : FontWeight.normal)),
                                    ],
                                  )),
                                  PopupMenuItem(value: 'title', child: Row(
                                    children: [
                                      Icon(Icons.sort_by_alpha_rounded, size: 18, color: _librarySort == 'title' ? Theme.of(context).colorScheme.primary : null),
                                      const SizedBox(width: 8),
                                      Text('Title', style: TextStyle(fontWeight: _librarySort == 'title' ? FontWeight.bold : FontWeight.normal)),
                                    ],
                                  )),
                                ],
                              ),
                              const SizedBox(width: 4),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

          // ── Discovery Sections ──
          _buildDiscoverySection(
            context,
            title: 'Trending',
            icon: Icons.trending_up_rounded,
            async: ref.watch(trendingAudiobooksProvider),
            onSeeMore: () => _openCatalogScreen(context, 'Trending', ref.read(trendingAudiobooksProvider)),
          ),
          _buildDiscoverySection(
            context,
            title: 'New Releases',
            icon: Icons.fiber_new_rounded,
            async: ref.watch(newReleasesAudiobooksProvider),
            onSeeMore: () => _openCatalogScreen(context, 'New Releases', ref.read(newReleasesAudiobooksProvider)),
          ),
          _buildDiscoverySection(
            context,
            title: 'Top Rated',
            icon: Icons.star_rounded,
            async: ref.watch(topRatedAudiobooksProvider),
            onSeeMore: () => _openCatalogScreen(context, 'Top Rated', ref.read(topRatedAudiobooksProvider)),
          ),
          _buildDiscoverySection(
            context,
            title: 'Free Classics',
            icon: Icons.auto_stories_rounded,
            async: ref.watch(freeClassicsProvider),
            onSeeMore: () => _openCatalogScreen(context, 'Free Classics', ref.read(freeClassicsProvider)),
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
                              builder: (_) => AudiobookCatalogAllScreen(title: 'Browse Audiobooks', catalog: catalog),
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

  String _detectFormat(AudiobookResult book) {
    final title = book.title.toLowerCase();
    final desc = (book.description ?? '').toLowerCase();
    
    if (title.contains('.epub') || title.contains(' epub ') || title.contains('(epub)') || title.contains('[epub]')) {
      return 'EPUB';
    }
    if (title.contains('.pdf') || title.contains(' pdf ') || title.contains('(pdf)') || title.contains('[pdf]')) {
      return 'PDF';
    }
    if (title.contains('.mobi') || title.contains(' mobi ') || title.contains('(mobi)') || title.contains('[mobi]')) {
      return 'MOBI';
    }
    
    if (desc.contains('epub')) return 'EPUB';
    if (desc.contains('pdf')) return 'PDF';
    if (desc.contains('mobi')) return 'MOBI';
    
    return 'AUDIOBOOK';
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
      title: Text(
        book.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              if (isTorrent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
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
              Builder(builder: (context) {
                final format = _detectFormat(book);
                final Color bgColor;
                final Color fgColor;
                
                switch (format) {
                  case 'EPUB':
                    bgColor = Colors.orange.withValues(alpha: 0.15);
                    fgColor = Colors.orange.shade800;
                    break;
                  case 'PDF':
                    bgColor = Colors.red.withValues(alpha: 0.15);
                    fgColor = Colors.red.shade800;
                    break;
                  case 'MOBI':
                    bgColor = Colors.blue.withValues(alpha: 0.15);
                    fgColor = Colors.blue.shade800;
                    break;
                  default:
                    bgColor = Colors.green.withValues(alpha: 0.15);
                    fgColor = Colors.green.shade800;
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    format,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            book.author == 'Torrent Result' && book.description != null
                ? book.description!
                : book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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
              memCacheWidth: (width != null && width.isFinite) ? width.round() : null,
              memCacheHeight: (height != null && height.isFinite) ? height.round() : null,
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
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: progress.progressPercent,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(progress.progressPercent * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              progress.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _openCatalogScreen(BuildContext context, String title, AsyncValue<List<AudiobookResult>> asyncValue) {
    asyncValue.whenData((catalog) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudiobookCatalogAllScreen(title: title, catalog: catalog),
          ),
        );
      }
    });
  }

  Widget _buildDiscoverySection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required AsyncValue<List<AudiobookResult>> async,
    required VoidCallback onSeeMore,
  }) {
    return async.when(
      data: (books) {
        if (books.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final theme = Theme.of(context);
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: onSeeMore,
                        child: const Text('See More'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return _buildLocalBookCard(context, book);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class AudiobookCatalogAllScreen extends ConsumerStatefulWidget {
  final String title;
  final List<AudiobookResult> catalog;

  const AudiobookCatalogAllScreen({super.key, required this.title, required this.catalog});

  @override
  ConsumerState<AudiobookCatalogAllScreen> createState() => _AudiobookCatalogAllScreenState();
}

class _AudiobookCatalogAllScreenState extends ConsumerState<AudiobookCatalogAllScreen> {
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<AudiobookResult>? _searchResults;
  bool _isSearching = false;
  Timer? _searchDebounce;

  List<AudiobookResult> get _displayedCatalog => _searchResults ?? widget.catalog;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchItunes(String query) async {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }
    setState(() { _searchQuery = query; });

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      try {
        final repo = ref.read(audiobookRepositoryProvider);
        final results = await repo.searchItunesCatalog(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  String _formatDuration(int? millis) {
    if (millis == null || millis <= 0) return '';
    final duration = Duration(milliseconds: millis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'Switch to list view' : 'Switch to grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search iTunes catalog...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty || _searchResults != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _searchDebounce?.cancel();
                      setState(() {
                        _searchResults = null;
                        _isSearching = false;
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
              onChanged: _searchItunes,
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _displayedCatalog.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results for "$_searchQuery"'
                                  : 'No audiobooks available',
                              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : _isGridView
                        ? _buildGridView(_displayedCatalog)
                        : _buildListView(_displayedCatalog),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<AudiobookResult> catalog) {
    return GridView.builder(
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
    );
  }

  Widget _buildListView(List<AudiobookResult> catalog) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: catalog.length,
      itemBuilder: (context, index) {
        final book = catalog[index];
        return _buildListTileForAllScreen(context, book);
      },
    );
  }

  Widget _buildListTileForAllScreen(BuildContext context, AudiobookResult book) {
    final durationStr = _formatDuration(book.durationMillis);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: book.artworkUrl != null && book.artworkUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: book.artworkUrl!,
                    memCacheWidth: 56,
                    memCacheHeight: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: theme.colorScheme.surfaceContainerHighest),
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 28),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.book, size: 28),
                  ),
            ),
          ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
            if (durationStr.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    durationStr,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AudiobookDetailScreen(book: book)),
          );
        },
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


