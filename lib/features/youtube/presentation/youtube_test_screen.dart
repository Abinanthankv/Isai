import 'package:flutter/material.dart';
import '../data/youtube_video_service.dart';
import '../data/youtube_models.dart';
import 'youtube_now_playing_test_screen.dart';
import 'youtube_music_now_playing_test_screen.dart';

class YoutubeTestScreen extends StatefulWidget {
  const YoutubeTestScreen({super.key});

  @override
  State<YoutubeTestScreen> createState() => _YoutubeTestScreenState();
}

class _YoutubeTestScreenState extends State<YoutubeTestScreen> {
  final _service = YoutubeVideoService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<YoutubeSearchResult>? _results;
  bool _loading = false;
  String _status = '';

  @override
  void dispose() {
    _service.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _status = 'Searching...';
      _results = null;
    });

    final t0 = DateTime.now();
    final results = await _service.search(query.trim());
    final ms = DateTime.now().difference(t0).inMilliseconds;

    setState(() {
      _loading = false;
      _results = results;
      _status = 'Found ${results.length} results in ${ms}ms';
    });
  }

  Future<void> _selectVideo(YoutubeSearchResult result) async {
    setState(() {
      _loading = true;
      _status = 'Fetching streams for "${result.title}"...';
    });

    final t0 = DateTime.now();
    final info = await _service.getVideoInfo(result.id);
    final ms = DateTime.now().difference(t0).inMilliseconds;

    setState(() => _loading = false);

    if (info != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => YoutubeNowPlayingTestScreen(info: info, service: _service),
      ));
    } else {
      setState(() => _status = 'Failed to fetch (${ms}ms)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('YouTube Test'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_status, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
            ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
          else if (_results != null)
            Expanded(child: _buildResultsGrid(isDark))
          else
            Expanded(child: _buildInitialPrompt(isDark)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search YouTube...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _results = null;
                      _status = '';
                    });
                  },
                )
              : null,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        ),
        onSubmitted: _search,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildInitialPrompt(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text('Search for a YouTube video', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: 24),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _chip('Taylor Swift'),
            _chip('Rick Astley'),
            _chip('Lofi'),
            _chip('4K nature'),
          ]),
          const SizedBox(height: 32),
          const Divider(indent: 48, endIndent: 48, color: Colors.white12),
          const SizedBox(height: 16),
          TextButton.icon(
            icon: const Icon(Icons.music_video_rounded),
            label: const Text('Open YT Music Now Playing'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const YoutubeMusicNowPlayingTestScreen(),
            )),
            style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _searchController.text = label;
        _search(label);
      },
    );
  }

  Widget _buildResultsGrid(bool isDark) {
    if (_results!.isEmpty) {
      return Center(
        child: Text('No results', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
      );
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _results!.length,
      itemBuilder: (context, i) => _buildResultCard(_results![i], isDark),
    );
  }

  Widget _buildResultCard(YoutubeSearchResult r, bool isDark) {
    final mins = r.durationSeconds ~/ 60;
    final secs = r.durationSeconds % 60;
    final dur = r.durationSeconds > 0 ? '$mins:${secs.toString().padLeft(2, '0')}' : '';

    return GestureDetector(
      onTap: () => _selectVideo(r),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  r.thumbnailUrl != null
                      ? Image.network(r.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.grey[900]))
                      : Container(color: Colors.grey[900]),
                  if (dur.isNotEmpty)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                        child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 2),
                  Text(r.author, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


}
