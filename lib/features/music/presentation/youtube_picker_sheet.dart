import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../music/data/music_models.dart';
import 'music_providers.dart';

class YouTubePickerSheet extends ConsumerStatefulWidget {
  final ItunesTrack track;
  final void Function(YouTubeResult)? onPlayDirect;

  const YouTubePickerSheet({
    super.key, 
    required this.track,
    this.onPlayDirect,
  });

  @override
  ConsumerState<YouTubePickerSheet> createState() => _YouTubePickerSheetState();
}

class _YouTubePickerSheetState extends ConsumerState<YouTubePickerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(youtubeSearchProvider.notifier).search('${widget.track.artistName} ${widget.track.trackName}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(youtubeSearchProvider);

    // Handle side effects
    ref.listen<YouTubeSearchState>(
      youtubeSearchProvider,
      (previous, current) {
        if (current.addSuccess == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download started via TorBox WebDL!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else if (current.addSuccess == false && current.addError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error: ${current.addError}'), backgroundColor: Colors.red),
          );
        }
      },
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.ondemand_video, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'YouTube Results for ${widget.track.trackName}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.results.isEmpty
                        ? const Center(child: Text('No results found.', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            controller: controller,
                            itemCount: state.results.length,
                            itemBuilder: (context, index) {
                              final result = state.results[index];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(
                                    imageUrl: result.thumbnailUrl,
                                    width: 80,
                                    height: 45,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.video_collection, color: Colors.white54),
                                  ),
                                ),
                                title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text('${result.author} • ${result.duration}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.cloud_download, color: Colors.white54),
                                  onPressed: () => ref.read(youtubeSearchProvider.notifier).addWebDownload(result.videoUrl),
                                ),
                                onTap: () {
                                  if (widget.onPlayDirect != null) {
                                    widget.onPlayDirect!(result);
                                  } else {
                                    ref.read(youtubeSearchProvider.notifier).addWebDownload(result.videoUrl);
                                  }
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
