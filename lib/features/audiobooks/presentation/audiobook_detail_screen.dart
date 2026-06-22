import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:isai/core/theme/apple_music_theme.dart';
import 'package:isai/core/theme/glassmorphism.dart';
import 'package:isai/core/database/database.dart';
import 'audiobook_providers.dart';
import '../data/audiobook_models.dart';
import '../data/audiobook_repository.dart';
import 'audiobook_now_playing_screen.dart';
import 'package:isai/main.dart'; // For audioHandler
import 'package:audio_service/audio_service.dart';

class AudiobookDetailScreen extends ConsumerWidget {
  final AudiobookResult book;

  const AudiobookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalBook = book.id.startsWith('torrent:')
        ? book.copyWith(id: AudiobookRepository.normalizeBookId(book.id))
        : book;

    final chaptersAsync = ref.watch(bookChaptersProvider(normalBook.id));
    final detailsAsync = ref.watch(bookDetailsProvider(normalBook.id));
    final chapterProgressAsync = ref.watch(bookChapterProgressProvider(normalBook.id));
    final torrentStatusAsync = normalBook.id.startsWith('torrent:') 
        ? ref.watch(torrentStatusProvider(normalBook.id)) 
        : null;
    
    // Build a map of chapterIndex -> DbAudiobookProgress for quick lookup
    final Map<int, DbAudiobookProgress> chapterProgressMap = {};
    final progressList = chapterProgressAsync.value;
    if (progressList != null) {
      for (final p in progressList) {
        final progress = p as DbAudiobookProgress;
        chapterProgressMap[progress.chapterIndex] = progress;
      }
    }
    final hasProgress = chapterProgressMap.isNotEmpty;
    
    // Use enriched details if available, else fallback to passed book
    final displayBook = detailsAsync.value ?? normalBook;
    final downloadState = ref.watch(audiobookDownloadProvider)[displayBook.id];

    // Proactively cache metadata to ensure the DB registers the correct title/author immediately.
    // We cache displayBook which contains enriched details if loaded, rather than normalBook.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audiobookRepositoryProvider).cacheBookMetadata(displayBook);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Header with Blurred Background
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                displayBook.title,
                style: const TextStyle(shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))
                ]),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (displayBook.artworkUrl != null) ...[
                    _buildArtworkImage(displayBook.artworkUrl, isBlur: true, context: context),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildArtworkImage(displayBook.artworkUrl, isBlur: false, context: context),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.book,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Book Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By ${displayBook.author}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (displayBook.narrator != null && displayBook.narrator!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Narrated by ${displayBook.narrator}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (displayBook.id.startsWith('local:') || (displayBook.id.startsWith('torrent:') && torrentStatusAsync?.value?['inLibrary'] == true)) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showMetadataSearchSheet(context, ref, displayBook),
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: const Text('Fetch Online Metadata'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  if (torrentStatusAsync != null) ...[
                    const SizedBox(height: 12),
                    torrentStatusAsync.when(
                      data: (status) {
                        final inLibrary = status['inLibrary'] as bool? ?? false;
                        final cached = status['cached'] as bool? ?? false;
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cached 
                                  ? Colors.green.withOpacity(0.15) 
                                  : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: cached ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cached ? Icons.check_circle_rounded : Icons.offline_bolt_rounded,
                                    size: 14,
                                    color: cached ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    cached ? 'Cached on TorBox' : 'Uncached',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: cached ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: inLibrary 
                                  ? Colors.blue.withOpacity(0.15) 
                                  : Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: inLibrary ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    inLibrary ? Icons.folder_special_rounded : Icons.create_new_folder_rounded,
                                    size: 14,
                                    color: inLibrary ? Colors.blue : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    inLibrary ? 'In Library' : 'Add to TorBox',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: inLibrary ? Colors.blue : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, _) => const SizedBox.shrink(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (displayBook.description != null && displayBook.description!.isNotEmpty) ...[
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpandableDescription(
                      htmlText: displayBook.description!,
                      baseStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ) ?? const TextStyle(),
                    ),
                  ],
                  // Show progress summary card if user has listening progress
                  if (hasProgress) ...[
                    const SizedBox(height: 16),
                    _buildOverallProgressCard(context, chapterProgressMap, chaptersAsync.value?.length ?? 0, chaptersAsync.value ?? []),
                  ]
                  // Show download button ONLY if it's a torrent that is NOT yet in library
                  else if (displayBook.id.startsWith('torrent:')) ...[  
                    Builder(builder: (context) {
                      // Check if the torrent is already in the user's TorBox library
                      final inLibrary = torrentStatusAsync?.value?['inLibrary'] == true;
                      if (inLibrary) {
                        // Already in library — no need to download, chapters will appear above
                        return const SizedBox.shrink();
                      }
                      // Not yet in library - show download button
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.cloud_download_rounded),
                            label: const Text('Download Torrent to TorBox'),

                            onPressed: () async {
                              final parts = book.id.split(':');
                              final magnet = parts.length > 2 ? Uri.decodeComponent(parts[2]) : '';
                              if (magnet.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Adding torrent to TorBox...')),
                                );
                                final success = await ref.read(audiobookRepositoryProvider).addTorrent(magnet);
                                if (context.mounted) {
                                  if (success) {
                                    ref.invalidate(bookChaptersProvider(displayBook.id));
                                    ref.invalidate(torrentStatusProvider(displayBook.id));
                                    ref.invalidate(localAudiobooksProvider);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success 
                                        ? 'Torrent added to TorBox successfully! Refreshing details...' 
                                        : 'Failed to add torrent to TorBox.'),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No magnet link available for this torrent.')),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                  // Local Download Options for Library Book
                  chaptersAsync.when(
                    data: (chapters) {
                      if (chapters.isEmpty) return const SizedBox.shrink();
                      final isLibraryBook = displayBook.id.startsWith('torrent:') && torrentStatusAsync?.value?['inLibrary'] == true;
                      if (!isLibraryBook) return const SizedBox.shrink();

                      final allLocal = chapters.every((ch) => ch.streamUrl != null && (ch.streamUrl!.startsWith('/') || ch.streamUrl!.startsWith('file://')));
                      final progress = downloadState?.progress ?? -100.0; // dummy initial value

                      if (allLocal) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.offline_pin_rounded, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Downloaded to Device',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text('Delete'),
                                onPressed: () {
                                  ref.read(audiobookDownloadProvider.notifier).deleteDownloadedBook(displayBook, chapters);
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      if (downloadState != null && downloadState.status == 'downloading' && progress >= 0.0 && progress < 1.0) {
                        final downloadedMB = (downloadState.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
                        final totalMB = downloadState.totalBytes > 0 
                            ? '${(downloadState.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB' 
                            : 'Unknown size';
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              downloadState.totalChapters > 1
                                                  ? 'Downloading: File ${downloadState.currentChapterIndex}/${downloadState.totalChapters}'
                                                  : 'Downloading audiobook...',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          downloadState.currentChapterTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$downloadedMB MB / $totalMB (${(progress * 100).round()}%)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.pause_rounded, size: 18),
                                    label: const Text('Pause'),
                                    onPressed: () {
                                      ref.read(audiobookDownloadProvider.notifier).pauseBook(displayBook.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: progress),
                            ],
                          ),
                        );
                      }

                      if (progress == -4.0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Download Paused',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                        label: const Text('Resume'),
                                        onPressed: () {
                                          ref.read(audiobookDownloadProvider.notifier).downloadBook(displayBook, chapters);
                                        },
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        label: const Text('Clear'),
                                        onPressed: () {
                                          ref.read(audiobookDownloadProvider.notifier).deleteDownloadedBook(displayBook, chapters);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      if (progress == -5.0) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Spacer(),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Deleting files...', style: TextStyle(fontSize: 13)),
                              Spacer(),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download_for_offline_rounded),
                            label: const Text('Download Book to Device'),
                            onPressed: () {
                              ref.read(audiobookDownloadProvider.notifier).downloadBook(displayBook, chapters);
                            },
                          ),
                          if (progress < 0.0 && progress != -4.0 && progress != -5.0 && progress != -100.0) ...[
                            const SizedBox(height: 4),
                            Text(
                              progress == -1.0
                                  ? 'Error: Please set an audiobook folder in Settings first.'
                                  : progress == -2.0
                                      ? 'Error: Storage permission denied.'
                                      : 'Error: Download failed. Please try again.',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chapters',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          
          // Chapter List
          chaptersAsync.when(
            data: (chapters) {
              if (chapters.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: true,
                  child: Consumer(
                    builder: (context, ref, child) {
                      // Helper to clean search string for torrent indexers
                      String sanitizeTorrentQuery(String title, String author) {
                        String cleanTitle = title.replaceAll(RegExp(r'\([^)]*\)'), '');
                        cleanTitle = cleanTitle.replaceAll(RegExp(r'\[[^\]]*\]'), '');
                        if (cleanTitle.contains(':')) {
                          cleanTitle = cleanTitle.split(':').first;
                        }
                        if (cleanTitle.contains(' - ')) {
                          cleanTitle = cleanTitle.split(' - ').first;
                        }
                        cleanTitle = cleanTitle
                            .replaceAll(RegExp(r'\b(unabridged|abridged|novel|audiobook|book \d+)\b', caseSensitive: false), '')
                            .trim();
                        return '$cleanTitle $author'.replaceAll(RegExp(r'\s+'), ' ').trim();
                      }

                      final searchQuery = sanitizeTorrentQuery(displayBook.title, displayBook.author);
                      final torrentsAsync = ref.watch(bookTorrentSearchProvider(searchQuery));
                      
                      return torrentsAsync.when(
                        data: (torrents) {
                          if (torrents.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: Text('No chapters or torrent search results found.')),
                            );
                          }
                          
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  child: Text(
                                    'No direct streams found. Search results from torrents:',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: torrents.length,
                                  itemBuilder: (context, index) {
                                    final torrentBook = torrents[index];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: torrentBook.artworkUrl != null && torrentBook.artworkUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: torrentBook.artworkUrl!,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) => Container(
                                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                  ),
                                                  errorWidget: (_, __, ___) => Container(
                                                    color: Theme.of(context).colorScheme.tertiaryContainer,
                                                    child: Icon(
                                                      Icons.download_for_offline_rounded,
                                                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Theme.of(context).colorScheme.tertiaryContainer,
                                                  child: Icon(
                                                    Icons.download_for_offline_rounded,
                                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      title: Text(
                                        torrentBook.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        torrentBook.description ?? 'Torrent file',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.cloud_download_rounded),
                                        color: Theme.of(context).colorScheme.primary,
                                        iconSize: 28,
                                        onPressed: () async {
                                          String bookId = torrentBook.id;
                                          if (bookId.startsWith('audiobookbay:')) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Resolving AudiobookBay torrent info...')),
                                            );
                                            final resolved = await ref.read(audiobookRepositoryProvider).getBookDetails(bookId);
                                            if (resolved != null && resolved.id.startsWith('torrent:')) {
                                              bookId = resolved.id;
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Failed to resolve AudiobookBay torrent.')),
                                                );
                                              }
                                              return;
                                            }
                                          }
                                          
                                          final parts = bookId.split(':');
                                          final magnet = parts.length > 2 ? Uri.decodeComponent(parts[2]) : '';
                                          if (magnet.isNotEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Adding torrent to TorBox...')),
                                            );
                                            
                                            // Cache this book with normalized torrent ID (no magnet part)
                                            // so it's found when opened from the library later
                                            final normalizedTorrentId = AudiobookRepository.normalizeBookId(bookId);
                                            final torrentAssociatedBook = AudiobookResult(
                                              id: normalizedTorrentId,
                                              title: displayBook.title,
                                              author: displayBook.author,
                                              artworkUrl: displayBook.artworkUrl,
                                              description: displayBook.description,
                                            );
                                            await ref.read(audiobookRepositoryProvider).cacheBookMetadata(torrentAssociatedBook);
  
                                            final success = await ref.read(audiobookRepositoryProvider).addTorrent(magnet);
                                            if (context.mounted) {
                                              if (success) {
                                                ref.invalidate(localAudiobooksProvider);
                                                ref.invalidate(inProgressAudiobooksProvider);
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AudiobookDetailScreen(book: torrentAssociatedBook),
                                                  ),
                                                );
                                              }
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(success 
                                                    ? 'Torrent added successfully! Loading torrent chapter list...' 
                                                    : 'Failed to add torrent to TorBox.'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(50),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Searching torrents...'),
                              ],
                            ),
                          ),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Text('Failed to search torrents: $e')),
                        ),
                      );
                    },
                  ),
                );
              }
                           return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = chapters[index];
                    final chProgress = chapterProgressMap[index];
                    final bool isCompleted = chProgress?.isCompleted ?? false;
                    final double chapterPercent = (chProgress != null && chProgress.durationMillis > 0)
                        ? (chProgress.positionMillis / chProgress.durationMillis).clamp(0.0, 1.0)
                        : (isCompleted ? 1.0 : 0.0);

                    return StreamBuilder<MediaItem?>(
                      stream: audioHandler.mediaItem,
                      initialData: audioHandler.mediaItem.value,
                      builder: (context, mediaSnapshot) {
                        final currentMedia = mediaSnapshot.data;
                        final isCurrentBook = currentMedia?.extras?['bookId'] == normalBook.id;
                        final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);

                        bool isCurrent = false;
                        if (isCurrentBook) {
                          if (hasOffsets) {
                            final currentPosMs = audioHandler.playbackState.value.position.inMilliseconds;
                            final start = chapter.startTimeMillis;
                            final end = (index + 1 < chapters.length)
                                ? chapters[index + 1].startTimeMillis
                                : double.infinity;
                            isCurrent = currentPosMs >= start && currentPosMs < end;
                          } else {
                            isCurrent = (currentMedia?.extras?['chapterIndex'] == index) || (currentMedia?.title == chapter.title);
                          }
                        }

                        if (isCurrent) {
                          return StreamBuilder<Duration>(
                            stream: AudioService.position,
                            initialData: Duration.zero,
                            builder: (context, posSnapshot) {
                              final currentPos = posSnapshot.data ?? Duration.zero;
                              final currentPosMs = currentPos.inMilliseconds;
                              
                              return _buildChapterTile(
                                context: context,
                                index: index,
                                chapter: chapter,
                                chProgress: chProgress,
                                isCompleted: isCompleted,
                                chapterPercent: chapterPercent,
                                downloadState: downloadState,
                                isCurrent: true,
                                displayBook: displayBook,
                                normalizedId: normalBook.id,
                                currentPosMs: currentPosMs,
                                chapters: chapters,
                              );
                            },
                          );
                        } else {
                          return _buildChapterTile(
                            context: context,
                            index: index,
                            chapter: chapter,
                            chProgress: chProgress,
                            isCompleted: isCompleted,
                            chapterPercent: chapterPercent,
                            downloadState: downloadState,
                            isCurrent: false,
                            displayBook: displayBook,
                            normalizedId: normalBook.id,
                            chapters: chapters,
                          );
                        }
                      },
                    );
                  },
                  childCount: chapters.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (e, st) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Error loading chapters',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // padding for bottom bar
        ],
      ),
    );
  }

  Widget _buildChapterTile({
    required BuildContext context,
    required int index,
    required AudiobookChapter chapter,
    required DbAudiobookProgress? chProgress,
    required bool isCompleted,
    required double chapterPercent,
    required dynamic downloadState,
    required bool isCurrent,
    required AudiobookResult displayBook,
    required String normalizedId,
    int? currentPosMs,
    required List<AudiobookChapter> chapters,
  }) {
    final start = chapter.startTimeMillis;
    final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);
    
    int chDuration = chapter.durationMillis;
    if (hasOffsets) {
      final end = (index + 1 < chapters.length)
          ? chapters[index + 1].startTimeMillis
          : 0;
      if (end > start) {
        chDuration = (end - start).toInt();
      } else if (chProgress != null && chProgress.durationMillis > 0) {
        chDuration = chProgress.durationMillis;
      } else {
        final totalDurationMs = audioHandler.mediaItem.value?.duration?.inMilliseconds;
        if (totalDurationMs != null && totalDurationMs > start) {
          chDuration = (totalDurationMs - start).toInt();
        }
      }
    }
    if (chDuration <= 0) {
      chDuration = chapter.durationMillis > 0 ? chapter.durationMillis : 1;
    }

    int displayPos = 0;
    double percent = 0.0;
    if (isCurrent) {
      final activePos = currentPosMs ?? audioHandler.playbackState.value.position.inMilliseconds;
      if (hasOffsets) {
        displayPos = (activePos - start).clamp(0, chDuration);
      } else {
        displayPos = activePos.clamp(0, chDuration);
      }
      percent = (chDuration > 0) ? (displayPos / chDuration).clamp(0.0, 1.0) : 0.0;
    } else if (isCompleted) {
      displayPos = chDuration;
      percent = 1.0;
    } else if (chProgress != null) {
      if (hasOffsets) {
        // chProgress.positionMillis is absolute in DB
        displayPos = (chProgress.positionMillis - start).clamp(0, chDuration);
      } else {
        displayPos = chProgress.positionMillis.clamp(0, chDuration);
      }
      percent = (chDuration > 0) ? (displayPos / chDuration).clamp(0.0, 1.0) : 0.0;
    }

    return Consumer(
      builder: (context, ref, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer
                          : (isCompleted
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                              : Theme.of(context).colorScheme.secondaryContainer),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCurrent
                          ? Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 18)
                          : (isCompleted
                              ? Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary)
                              : (downloadState != null && downloadState.status == 'downloading' && downloadState.currentChapterIndex == index + 1)
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    )
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )),
                    ),
                  ),
                  if (!isCompleted && percent > 0.0)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 2.5,
                        backgroundColor: Colors.transparent,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
              title: Text(
                chapter.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : (isCompleted ? Theme.of(context).colorScheme.onSurfaceVariant : null),
                ),
              ),
              subtitle: (downloadState != null && downloadState.status == 'downloading' && downloadState.currentChapterIndex == index + 1)
                  ? Text(
                      'Downloading... ${(downloadState.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB' +
                          (downloadState.totalBytes > 0
                              ? ' / ${(downloadState.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                              : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : (isCurrent
                      ? Text(
                          'Playing • ${_formatDuration(displayPos)} / ${_formatDuration(chDuration)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : (percent > 0.0
                          ? Text(
                              isCompleted
                                  ? 'Completed'
                                  : '${_formatDuration(displayPos)} / ${_formatDuration(chDuration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCompleted
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : (chDuration > 0 && chDuration != 1
                              ? Text(
                                  _formatDuration(chDuration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null))),
              trailing: IconButton(
                icon: Icon(isCurrent 
                    ? Icons.pause_circle_filled_rounded 
                    : (isCompleted ? Icons.replay_circle_filled_rounded : Icons.play_circle_fill)),
                color: Theme.of(context).colorScheme.primary,
                iconSize: 36,
                onPressed: () async {
                  if (isCurrent) {
                    final playbackState = audioHandler.playbackState.value;
                    if (playbackState.playing) {
                      await audioHandler.pause();
                    } else {
                      await audioHandler.play();
                    }
                    return;
                  }

                  // Cache metadata and save initial progress immediately to DB so it shows in Continue Listening
                  final repo = ref.read(audiobookRepositoryProvider);
                  await repo.cacheBookMetadata(displayBook.copyWith(id: normalizedId));

                  final initialPos = (chProgress?.positionMillis != null && chProgress!.positionMillis > 0)
                      ? chProgress.positionMillis
                      : chapter.startTimeMillis;
                  final totalDur = chProgress?.durationMillis ?? chapter.durationMillis;

                  await repo.saveProgress(
                    bookId: normalizedId,
                    chapterIndex: index,
                    positionMillis: initialPos,
                    durationMillis: totalDur,
                  );

                  // CRITICAL: Play via AudioHandler with mediaType guard
                  await audioHandler.customAction('play', {
                    'url': chapter.streamUrl ?? '',
                    'title': chapter.title,
                    'artist': displayBook.author,
                    'artworkUrl': displayBook.artworkUrl ?? '',
                    'forceReplace': true,
                    'mediaType': 'audiobook', // CRITICAL GUARD
                    'extras': {
                      'bookId': normalizedId,
                      'chapterIndex': index,
                      'initialPositionMillis': initialPos,
                    },
                  });
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AudiobookNowPlayingScreen(book: displayBook.copyWith(id: normalizedId)),
                      ),
                    );
                  }
                },
              ),
            ),
            if (chProgress != null && !isCompleted && !isCurrent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(
                  value: chapterPercent,
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(1),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build an overall progress summary card.
  Widget _buildOverallProgressCard(
    BuildContext context,
    Map<int, DbAudiobookProgress> progressMap,
    int totalChapters,
    List<AudiobookChapter> chapters,
  ) {
    final completedChapters = progressMap.values.where((p) => p.isCompleted).length;
    final listenedChapters = progressMap.length;
    final hasOffsets = chapters.any((ch) => ch.startTimeMillis > 0);

    int totalListenedMillis = 0;
    int totalDurationMillis = 0;

    if (hasOffsets && chapters.isNotEmpty) {
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final start = chapter.startTimeMillis;
        final end = (i + 1 < chapters.length)
            ? chapters[i + 1].startTimeMillis
            : 0;
        
        int chDuration = chapter.durationMillis;
        if (end > start) {
          chDuration = (end - start).toInt();
        } else if (progressMap.isNotEmpty) {
          final overallProgressEntry = progressMap.values.firstWhere((p) => p.durationMillis > 3600000, orElse: () => progressMap.values.first);
          if (overallProgressEntry.durationMillis > start) {
            chDuration = (overallProgressEntry.durationMillis - start).toInt();
          }
        }
        if (chDuration <= 0) {
          chDuration = chapter.durationMillis > 0 ? chapter.durationMillis : 1;
        }

        totalDurationMillis += chDuration;

        final chProgress = progressMap[i];
        if (chProgress != null) {
          if (chProgress.isCompleted) {
            totalListenedMillis += chDuration;
          } else {
            final relativePos = (chProgress.positionMillis - start).clamp(0, chDuration);
            totalListenedMillis += relativePos;
          }
        }
      }
    } else {
      for (final p in progressMap.values) {
        totalDurationMillis += p.durationMillis;
        if (p.isCompleted) {
          totalListenedMillis += p.durationMillis;
        } else {
          totalListenedMillis += p.positionMillis;
        }
      }
    }

    final double overallPercent;
    if (totalDurationMillis > 0) {
      overallPercent = (totalListenedMillis / totalDurationMillis).clamp(0.0, 1.0);
    } else if (totalChapters > 0) {
      overallPercent = (completedChapters / totalChapters).clamp(0.0, 1.0);
    } else {
      overallPercent = 0.0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.headphones_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Progress',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${(overallPercent * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overallPercent,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildProgressStat(
                context,
                Icons.check_circle_outline_rounded,
                '$completedChapters / ${totalChapters > 0 ? totalChapters : listenedChapters}',
                'Chapters done',
              ),
              const SizedBox(width: 24),
              _buildProgressStat(
                context,
                Icons.timer_outlined,
                _formatDuration(totalListenedMillis),
                'Time listened',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(BuildContext context, IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Format milliseconds to a human readable duration string.
  String _formatDuration(int millis) {
    final duration = Duration(milliseconds: millis);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildArtworkImage(String? url, {required bool isBlur, required BuildContext context}) {
    if (url == null || url.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.book,
            size: isBlur ? 120 : 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final cleanPath = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;

    if (isLocal) {
      return Image.file(
        File(cleanPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.book,
              size: isBlur ? 120 : 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
        errorWidget: (_, __, ___) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.book,
              size: isBlur ? 120 : 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
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
}

class MetadataSearchWidget extends ConsumerStatefulWidget {
  final AudiobookResult currentBook;
  final ScrollController scrollController;

  const MetadataSearchWidget({
    required this.currentBook,
    required this.scrollController,
  });

  @override
  ConsumerState<MetadataSearchWidget> createState() => _MetadataSearchWidgetState();
}

class _MetadataSearchWidgetState extends ConsumerState<MetadataSearchWidget> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  List<AudiobookResult> _results = [];
  String _error = '';

  StreamSubscription<List<AudiobookResult>>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentBook.title);
    _performSearch();
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    await _searchSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _error = '';
      _results = [];
    });

    final repo = ref.read(audiobookRepositoryProvider);
    _searchSubscription = repo.searchOnlineMetadataStream(query).listen(
      (results) {
        if (mounted) {
          setState(() {
            _results = results;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _selectBook(AudiobookResult selectedBook) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(audiobookRepositoryProvider);
      final fullBook = await repo.fetchFullOnlineMetadata(selectedBook);

      final mergedBook = AudiobookResult(
        id: widget.currentBook.id,
        title: fullBook.title,
        author: fullBook.author,
        artworkUrl: fullBook.artworkUrl ?? widget.currentBook.artworkUrl,
        description: (fullBook.description != null && fullBook.description!.isNotEmpty) 
            ? fullBook.description! 
            : 'Audiobook stored locally/in library',
        totalChapters: widget.currentBook.totalChapters,
      );

      await repo.cacheBookMetadata(mergedBook);

      ref.invalidate(bookDetailsProvider(widget.currentBook.id));
      ref.invalidate(localAudiobooksProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metadata updated successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to apply metadata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Search book title...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _controller.clear(),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _performSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                    : _results.isEmpty
                        ? const Center(child: Text('No metadata results found.'))
                        : ListView.builder(
                            controller: widget.scrollController,
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: item.artworkUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: item.artworkUrl!,
                                          width: 45,
                                          height: 45,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 45,
                                          height: 45,
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.book, size: 20),
                                        ),
                                ),
                                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    if (item.language != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.language!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Expanded(
                                      child: Text(item.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _selectBook(item),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

Widget _buildHtmlDescription(BuildContext context, String htmlText, TextStyle baseStyle, {int? maxLines}) {
  var text = htmlText
      .replaceAll('<br>', '\n')
      .replaceAll('<br/>', '\n')
      .replaceAll('<br />', '\n')
      .replaceAll('<p>', '')
      .replaceAll('</p>', '\n\n')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  final tagRegex = RegExp(r'(<[^>]+>)');
  final parts = text.split(tagRegex);
  final matches = tagRegex.allMatches(text).toList();

  final List<TextSpan> spans = [];
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;

  for (int i = 0; i < parts.length; i++) {
    if (parts[i].isNotEmpty) {
      spans.add(TextSpan(
        text: parts[i],
        style: baseStyle.copyWith(
          fontWeight: isBold ? FontWeight.bold : baseStyle.fontWeight,
          fontStyle: isItalic ? FontStyle.italic : baseStyle.fontStyle,
          decoration: isUnderline ? TextDecoration.underline : baseStyle.decoration,
        ),
      ));
    }

    if (i < matches.length) {
      final tag = matches[i].group(0)!.toLowerCase();
      if (tag == '<b>' || tag == '<strong>') {
        isBold = true;
      } else if (tag == '</b>' || tag == '</strong>') {
        isBold = false;
      } else if (tag == '<i>' || tag == '<em>') {
        isItalic = true;
      } else if (tag == '</i>' || tag == '</em>') {
        isItalic = false;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      }
    }
  }

  return RichText(
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    text: TextSpan(
      children: spans,
      style: baseStyle,
    ),
  );
}

class ExpandableDescription extends StatefulWidget {
  final String htmlText;
  final TextStyle baseStyle;

  const ExpandableDescription({
    super.key,
    required this.htmlText,
    required this.baseStyle,
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Approximate calculation to check if text exceeds 4 lines
        final cleanText = widget.htmlText.replaceAll(RegExp(r'<[^>]+>'), '');
        final span = TextSpan(text: cleanText, style: widget.baseStyle);
        final tp = TextPainter(
          text: span,
          maxLines: 4,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final exceeds = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHtmlDescription(
              context,
              widget.htmlText,
              widget.baseStyle,
              maxLines: _isExpanded ? null : 4,
            ),
            if (exceeds) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(
                  _isExpanded ? 'Read Less' : 'Read More',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
