import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../music/data/music_models.dart';
import 'music_providers.dart';

/// Bottom sheet that shows Apibay results for a selected iTunes track
class TorrentPickerSheet extends ConsumerStatefulWidget {
  final ItunesTrack track;
  const TorrentPickerSheet({super.key, required this.track});

  @override
  ConsumerState<TorrentPickerSheet> createState() => _TorrentPickerSheetState();
}

class _TorrentPickerSheetState extends ConsumerState<TorrentPickerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(torrentSearchProvider.notifier).searchTorrents(widget.track.torrentQuery);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(torrentSearchProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add to TorBox',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${widget.track.artistName} · ${widget.track.collectionName}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (state.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (state.results.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No torrents found', 
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.results.length,
                itemBuilder: (ctx, i) {
                  final result = state.results[i];
                  final resultHash = result.infoHash.toLowerCase();
                  final isCached = state.cachedHashes.contains(resultHash);
                  
                  return ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isCached) ...[
                          const Icon(Icons.bolt, size: 14, color: Colors.yellowAccent),
                          const SizedBox(width: 4),
                        ],
                        _SourceBadge(source: result.source),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          '${result.seeders}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' seeders',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, 
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${result.formattedSize}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, 
                            fontSize: 12,
                          ),
                        ),
                        if (isCached) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant, 
                              fontSize: 12,
                            ),
                          ),
                         
                        ],
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        await ref.read(torrentSearchProvider.notifier).addToTorBox(result);
                        if (mounted) {
                          final success = ref.read(torrentSearchProvider).addSuccess;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success == true
                                  ? (isCached ? '⚡ Instant Added to TorBox!' : '✅ Added to TorBox!')
                                  : '❌ Failed to add'),
                              backgroundColor: success == true ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCached ? Colors.orange : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(isCached ? 'Instant⚡' : 'Add'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (source.toLowerCase()) {
      case 'apibay':
        color = Colors.orange;
        break;
      case '1337x':
        color = Colors.redAccent;
        break;
      case 'piratebay':
      case 'pirate bay':
        color = Colors.blue;
        break;
      case 'rutracker':
      case 'knaben':
        color = Colors.tealAccent;
        break;
      case 'nyaa':
        color = Colors.cyanAccent;
        break;
      case 'bitsearch':
        color = Colors.purpleAccent;
        break;
      default:
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        source.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
