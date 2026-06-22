import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

/// A full-screen EPUB reader widget that uses the `archive` package to
/// parse EPUB files and displays chapter content with chapter navigation.
class EpubReaderScreen extends StatefulWidget {
  final String epubFilePath;
  final String bookId;
  final VoidCallback? onClose;

  const EpubReaderScreen({
    super.key,
    required this.epubFilePath,
    required this.bookId,
    this.onClose,
  });

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  List<_EpubChapter> _chapters = [];
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  double _fontSize = 16.0;
  bool _showControls = true;
  double _pendingScrollRestore = 0.0; // deferred scroll offset to restore
  DateTime _lastScrollSave = DateTime.fromMillisecondsSinceEpoch(0);

  static const String _prefKeyChapter = 'epub_chapter_';
  static const String _prefKeyScroll = 'epub_scroll_';
  static const String _prefKeyFontSize = 'epub_fontsize_';

  @override
  void initState() {
    super.initState();
    _loadEpub();
    // Auto-save scroll position while reading (throttled to every 3s)
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final now = DateTime.now();
    if (now.difference(_lastScrollSave).inSeconds >= 3) {
      _lastScrollSave = now;
      _saveProgress();
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_prefKeyChapter}${widget.bookId}', _currentChapterIndex);
      await prefs.setDouble('${_prefKeyScroll}${widget.bookId}', _scrollController.hasClients ? _scrollController.offset : 0.0);
      await prefs.setDouble('${_prefKeyFontSize}${widget.bookId}', _fontSize);
    } catch (_) {}
  }

  Future<void> _restoreProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChapter = prefs.getInt('${_prefKeyChapter}${widget.bookId}') ?? 0;
      final savedFontSize = prefs.getDouble('${_prefKeyFontSize}${widget.bookId}') ?? 16.0;
      final savedScroll = prefs.getDouble('${_prefKeyScroll}${widget.bookId}') ?? 0.0;
      
      setState(() {
        _fontSize = savedFontSize;
        _currentChapterIndex = savedChapter.clamp(0, _chapters.length - 1);
        _pendingScrollRestore = savedScroll;
      });

      // Restore scroll after the list has fully laid out
      if (savedScroll > 0) {
        // Wait two frames: first for the list to build, second to get accurate extents
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyScrollRestore();
          });
        });
      }
    } catch (_) {}
  }

  void _applyScrollRestore() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      // Layout not ready yet — retry after a short delay
      Future.delayed(const Duration(milliseconds: 200), _applyScrollRestore);
      return;
    }
    final target = _pendingScrollRestore.clamp(0.0, maxExtent);
    _scrollController.jumpTo(target);
  }

  Future<void> _loadEpub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.epubFilePath);
      if (!await file.exists()) {
        setState(() {
          _error = 'EPUB file not found at:\n${widget.epubFilePath}';
          _isLoading = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the OPF file via container.xml
      final containerEntry = archive.findFile('META-INF/container.xml');
      if (containerEntry == null) {
        setState(() {
          _error = 'Invalid EPUB: Missing META-INF/container.xml';
          _isLoading = false;
        });
        return;
      }

      final containerXml = xml.XmlDocument.parse(utf8.decode(containerEntry.content as List<int>));
      final rootfilePath = containerXml
          .findAllElements('rootfile')
          .first
          .getAttribute('full-path');

      if (rootfilePath == null) {
        setState(() {
          _error = 'Invalid EPUB: Cannot find rootfile path';
          _isLoading = false;
        });
        return;
      }

      // Parse OPF for spine and manifest
      final opfEntry = archive.findFile(rootfilePath);
      if (opfEntry == null) {
        setState(() {
          _error = 'Invalid EPUB: Missing OPF file';
          _isLoading = false;
        });
        return;
      }

      final opfContent = utf8.decode(opfEntry.content as List<int>);
      final opfDoc = xml.XmlDocument.parse(opfContent);

      // Base dir for resolving relative paths
      final baseDir = rootfilePath.contains('/')
          ? rootfilePath.substring(0, rootfilePath.lastIndexOf('/') + 1)
          : '';

      // Build manifest id->href map
      final manifest = <String, String>{};
      for (final item in opfDoc.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        final mediaType = item.getAttribute('media-type') ?? '';
        if (id != null && href != null && mediaType.contains('html')) {
          manifest[id] = href;
        }
      }

      // Get spine order
      final spineItems = opfDoc.findAllElements('itemref').map((e) => e.getAttribute('idref')).whereType<String>().toList();

      // Get titles from NCX or navigation doc (optional — we'll use chapter numbers if not available)
      final ncxTitles = _extractNcxTitles(archive, baseDir, opfDoc);

      // Build chapters
      final chapters = <_EpubChapter>[];
      for (var i = 0; i < spineItems.length; i++) {
        final idref = spineItems[i];
        final href = manifest[idref];
        if (href == null) continue;

        final fullPath = '$baseDir$href'.replaceAll('../', '');
        final entry = archive.findFile(fullPath);
        if (entry == null) continue;

        final rawHtml = utf8.decode(entry.content as List<int>, allowMalformed: true);
        final text = _htmlToText(rawHtml);
        if (text.trim().isEmpty) continue;

        final title = (i < ncxTitles.length && ncxTitles[i].isNotEmpty)
            ? ncxTitles[i]
            : 'Chapter ${chapters.length + 1}';

        chapters.add(_EpubChapter(title: title, content: text));
      }

      if (chapters.isEmpty) {
        setState(() {
          _error = 'No readable chapters found in this EPUB.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });

      await _restoreProgress();
    } catch (e) {
      setState(() {
        _error = 'Failed to parse EPUB: $e';
        _isLoading = false;
      });
    }
  }

  List<String> _extractNcxTitles(Archive archive, String baseDir, xml.XmlDocument opfDoc) {
    final titles = <String>[];
    try {
      // Try NCX navigation
      for (final item in opfDoc.findAllElements('item')) {
        final mediaType = item.getAttribute('media-type') ?? '';
        if (mediaType.contains('ncx') || (item.getAttribute('href') ?? '').endsWith('.ncx')) {
          final href = item.getAttribute('href');
          if (href != null) {
            final ncxPath = '$baseDir$href';
            final ncxEntry = archive.findFile(ncxPath);
            if (ncxEntry != null) {
              final ncxDoc = xml.XmlDocument.parse(utf8.decode(ncxEntry.content as List<int>, allowMalformed: true));
              for (final navPoint in ncxDoc.findAllElements('navPoint')) {
                final label = navPoint.findElements('navLabel').first.findElements('text').first.innerText.trim();
                titles.add(label);
              }
            }
          }
          break;
        }
      }

      // Try nav.xhtml (EPUB3)
      if (titles.isEmpty) {
        for (final item in opfDoc.findAllElements('item')) {
          final props = item.getAttribute('properties') ?? '';
          if (props.contains('nav')) {
            final href = item.getAttribute('href');
            if (href != null) {
              final navPath = '$baseDir$href';
              final navEntry = archive.findFile(navPath);
              if (navEntry != null) {
                final navDoc = xml.XmlDocument.parse(utf8.decode(navEntry.content as List<int>, allowMalformed: true));
                for (final li in navDoc.findAllElements('li')) {
                  final a = li.findElements('a').firstOrNull;
                  if (a != null) titles.add(a.innerText.trim());
                }
              }
            }
            break;
          }
        }
      }
    } catch (_) {}
    return titles;
  }

  /// Converts HTML content to plain text by stripping all tags.
  String _htmlToText(String html) {
    // Remove style/script blocks
    var text = html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');

    // Add line breaks for block-level tags
    text = text
        .replaceAllMapped(RegExp(r'<(p|br|div|h[1-6]|li|blockquote|tr)[^>]*>', caseSensitive: false), (_) => '\n')
        .replaceAllMapped(RegExp(r'</(p|div|h[1-6]|blockquote|tr)[^>]*>', caseSensitive: false), (_) => '\n');

    // Remove all remaining tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8216;', '\u2018')
        .replaceAll('&#8217;', '\u2019')
        .replaceAll('&#8220;', '\u201C')
        .replaceAll('&#8221;', '\u201D')
        .replaceAll('&#8212;', '\u2014')
        .replaceAll('&#8211;', '\u2013');

    // Clean up excessive whitespace
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return text;
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _saveProgress();
    setState(() {
      _currentChapterIndex = index;
    });
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAF8F5);
    final textColor = isDark ? const Color(0xFFE8E0D8) : const Color(0xFF2D2420);
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? _buildLoading(bgColor, accentColor)
          : _error != null
              ? _buildError(bgColor, textColor)
              : _buildReader(bgColor, textColor, accentColor, isDark),
    );
  }

  Widget _buildLoading(Color bg, Color accent) {
    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: 16),
            Text('Loading book...', style: TextStyle(color: accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Color bg, Color textColor) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: textColor.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadEpub,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReader(Color bg, Color textColor, Color accent, bool isDark) {
    final chapter = _chapters[_currentChapterIndex];

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          // Main reading area
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 80, bottom: 100),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chapter title
                        Text(
                          chapter.title,
                          style: TextStyle(
                            fontSize: _fontSize + 6,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Chapter content
                        SelectableText(
                          chapter.content,
                          style: TextStyle(
                            fontSize: _fontSize,
                            color: textColor,
                            height: 1.75,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Navigation at bottom
                        Row(
                          children: [
                            if (_currentChapterIndex > 0)
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  label: const Text('Previous'),
                                  onPressed: () => _goToChapter(_currentChapterIndex - 1),
                                ),
                              ),
                            if (_currentChapterIndex > 0 && _currentChapterIndex < _chapters.length - 1)
                              const SizedBox(width: 12),
                            if (_currentChapterIndex < _chapters.length - 1)
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  label: const Text('Next'),
                                  onPressed: () => _goToChapter(_currentChapterIndex + 1),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Top controls bar
          AnimatedSlide(
            offset: _showControls ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              decoration: BoxDecoration(
                color: bg.withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(color: textColor.withOpacity(0.08)),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: widget.onClose,
                        tooltip: 'Back to player',
                      ),
                      Expanded(
                        child: Text(
                          chapter.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Font size controls
                      IconButton(
                        icon: const Icon(Icons.text_decrease_rounded, size: 20),
                        onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(12.0, 28.0)),
                        tooltip: 'Decrease font size',
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_increase_rounded, size: 20),
                        onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(12.0, 28.0)),
                        tooltip: 'Increase font size',
                      ),
                      // TOC button
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                        onPressed: () => _showToc(context, textColor, bg, accent),
                        tooltip: 'Table of contents',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom progress bar
          AnimatedSlide(
            offset: _showControls ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: bg.withOpacity(0.95),
                  border: Border(
                    top: BorderSide(color: textColor.withOpacity(0.08)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _currentChapterIndex.toDouble(),
                            min: 0,
                            max: (_chapters.length - 1).toDouble(),
                            divisions: _chapters.length > 1 ? _chapters.length - 1 : 1,
                            activeColor: accent,
                            inactiveColor: accent.withOpacity(0.2),
                            onChanged: (val) => _goToChapter(val.round()),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ch. ${_currentChapterIndex + 1} / ${_chapters.length}',
                              style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5)),
                            ),
                            Text(
                              '${((_currentChapterIndex + 1) / _chapters.length * 100).round()}% read',
                              style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToc(BuildContext context, Color textColor, Color bg, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Table of Contents',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (ctx, i) {
                final isCurrent = i == _currentChapterIndex;
                return ListTile(
                  leading: isCurrent
                      ? Icon(Icons.bookmark_rounded, color: accent, size: 20)
                      : SizedBox(
                          width: 20,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                  title: Text(
                    _chapters[i].title,
                    style: TextStyle(
                      color: isCurrent ? accent : textColor,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _goToChapter(i);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpubChapter {
  final String title;
  final String content;

  const _EpubChapter({required this.title, required this.content});
}

/// Utility to find an epub file in a given directory path.
Future<String?> findEpubInFolder(String folderPath) async {
  try {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;
    
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.epub')) {
          return entity.path;
        }
      }
    }
    
    // Also search one level deep
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.epub')) {
          return entity.path;
        }
      }
    }
  } catch (_) {}
  return null;
}
