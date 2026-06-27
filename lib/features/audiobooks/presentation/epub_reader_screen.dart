import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;
import 'package:path/path.dart' as p;
import '../../../core/di/injection.dart';
import '../data/audiobook_repository.dart';

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
  double _currentScrollOffset = 0.0; // tracks scroll position synchronously
  double _maxScrollExtent = 0.0; // tracks max scroll extent of current chapter
  double _pendingScrollRestore = 0.0; // deferred scroll offset to restore
  DateTime _lastScrollSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 25.0; // pixels per second
  Timer? _autoScrollTimer;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<int> _searchMatchPositions = [];
  int _currentMatchIndex = -1;
  String _readingTheme = 'original';
  bool _isPageMode = false;
  PageController? _pageController;

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });
    if (_isAutoScrolling) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      if (currentOffset >= maxExtent) {
        _stopAutoScroll();
        return;
      }
      
      // Speed represents pixels per second.
      // 50ms is 1/20 of a second, so we scroll (speed / 20) pixels.
      final nextOffset = currentOffset + (_autoScrollSpeed / 20.0);
      _scrollController.jumpTo(nextOffset.clamp(0.0, maxExtent));
      _currentScrollOffset = _scrollController.offset;
      _maxScrollExtent = maxExtent;
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    setState(() {
      _isAutoScrolling = false;
    });
  }

  static const String _prefKeyChapter = 'epub_chapter_';
  static const String _prefKeyScroll = 'epub_scroll_';
  static const String _prefKeyFontSize = 'epub_fontsize_';
  static const String _prefKeyTheme = 'epub_theme_';

  @override
  void initState() {
    super.initState();
    _loadEpub();
    // Auto-save scroll position while reading (throttled to every 3s)
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _currentScrollOffset = _scrollController.offset;
      _maxScrollExtent = _scrollController.position.maxScrollExtent;
    }
    final now = DateTime.now();
    if (now.difference(_lastScrollSave).inSeconds >= 3) {
      _lastScrollSave = now;
      _saveProgress();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _saveProgress();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_prefKeyChapter}${widget.bookId}', _currentChapterIndex);
      await prefs.setDouble('${_prefKeyScroll}${widget.bookId}', _currentScrollOffset);
      await prefs.setDouble('${_prefKeyFontSize}${widget.bookId}', _fontSize);
      await prefs.setString('${_prefKeyTheme}${widget.bookId}', _readingTheme);
      await prefs.setBool('epub_pagemode_${widget.bookId}', _isPageMode);
      
      if (_chapters.isNotEmpty) {
        await prefs.setInt('epub_total_chapters_${widget.bookId}', _chapters.length);
        
        // Calculate estimated pages
        int totalPages = 0;
        final chapterPages = <int>[];
        for (final ch in _chapters) {
          final pages = (ch.content.length / 1000.0).ceil().clamp(1, 999999);
          chapterPages.add(pages);
          totalPages += pages;
        }

        double scrollRatio = 0.0;
        if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
          scrollRatio = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
        } else if (_maxScrollExtent > 0) {
          scrollRatio = (_currentScrollOffset / _maxScrollExtent).clamp(0.0, 1.0);
        }

        int pagesRead = 0;
        for (int i = 0; i < _currentChapterIndex; i++) {
          pagesRead += chapterPages[i];
        }
        if (_currentChapterIndex < chapterPages.length) {
          pagesRead += (scrollRatio * chapterPages[_currentChapterIndex]).round();
        }
        pagesRead = pagesRead.clamp(0, totalPages);
        final progressPercent = totalPages > 0 ? pagesRead / totalPages : 0.0;

        await prefs.setInt('epub_pages_read_${widget.bookId}', pagesRead);
        await prefs.setInt('epub_total_pages_${widget.bookId}', totalPages);
        await prefs.setDouble('epub_progress_${widget.bookId}', progressPercent);

        // Update/create progress.json in the epub's parent folder
        try {
          final parentDir = File(widget.epubFilePath).parent;
          if (await parentDir.exists()) {
            final progressFile = File(p.join(parentDir.path, 'progress.json'));
            Map<String, dynamic> progressJson = {};
            if (await progressFile.exists()) {
              try {
                final content = await progressFile.readAsString();
                progressJson = jsonDecode(content) as Map<String, dynamic>;
              } catch (_) {}
            }
            
            progressJson['bookId'] = widget.bookId;
            progressJson['epubProgress'] = {
              'currentChapter': _currentChapterIndex,
              'totalChapters': _chapters.length,
              'scrollOffset': _currentScrollOffset,
              'pagesRead': pagesRead,
              'totalPages': totalPages,
              'progress': progressPercent,
              'fontSize': _fontSize,
              'lastReadAt': DateTime.now().toIso8601String(),
            };
            
            await progressFile.writeAsString(jsonEncode(progressJson));
            print('[EpubReaderScreen] Saved epub progress to progress.json');
          }
        } catch (_) {}

        // Also save to unified progress.json (primary source)
        try {
          final repo = getIt<AudiobookRepository>();
          await repo.saveEpubProgress(widget.bookId, {
            'currentChapter': _currentChapterIndex,
            'totalChapters': _chapters.length,
            'scrollOffset': _currentScrollOffset,
            'pagesRead': pagesRead,
            'totalPages': totalPages,
            'progress': progressPercent,
            'fontSize': _fontSize,
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _restoreProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChapter = prefs.getInt('${_prefKeyChapter}${widget.bookId}') ?? 0;
      final savedFontSize = prefs.getDouble('${_prefKeyFontSize}${widget.bookId}') ?? 16.0;
      final savedScroll = prefs.getDouble('${_prefKeyScroll}${widget.bookId}') ?? 0.0;
      final savedTheme = prefs.getString('${_prefKeyTheme}${widget.bookId}') ?? 'original';
      final savedPageMode = prefs.getBool('epub_pagemode_${widget.bookId}') ?? false;
      // Migrate legacy theme names
      final migrated = {'light': 'original', 'sepia': 'focus', 'dark': 'quiet'};
      final finalTheme = migrated[savedTheme] ?? savedTheme;
      
      setState(() {
        _fontSize = savedFontSize;
        _readingTheme = finalTheme;
        _isPageMode = savedPageMode;
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
      for (final item in _findLocalElements(opfDoc, 'item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        final mediaType = item.getAttribute('media-type') ?? '';
        if (id != null && href != null && mediaType.contains('html')) {
          manifest[id] = href;
        }
      }

      // Get spine order
      final spineItems = _findLocalElements(opfDoc, 'itemref')
          .map((e) => e.getAttribute('idref'))
          .whereType<String>()
          .toList();

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

        final richContent = _htmlToRichContent(rawHtml);
        chapters.add(_EpubChapter(
          title: title,
          content: text,
          richContent: richContent,
        ));
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

  /// Find elements by local name, ignoring XML namespace.
  /// EPUB3 uses namespaces (e.g. {http://www.idpf.org/2007/opf}item,
  /// {http://www.w3.org/1999/xhtml}li) while EPUB2 does not.
  List<xml.XmlElement> _findLocalElements(xml.XmlNode parent, String localName) {
    return parent.findAllElements(localName).toList()
      ..addAll(parent.findAllElements('{http://www.idpf.org/2007/opf}$localName'))
      ..addAll(parent.findAllElements('{http://www.w3.org/1999/xhtml}$localName'));
  }

  List<String> _extractNcxTitles(Archive archive, String baseDir, xml.XmlDocument opfDoc) {
    final titles = <String>[];
    try {
      // Try NCX navigation (EPUB2)
      for (final item in _findLocalElements(opfDoc, 'item')) {
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
        for (final item in _findLocalElements(opfDoc, 'item')) {
          final props = item.getAttribute('properties') ?? '';
          if (props.contains('nav')) {
            final href = item.getAttribute('href');
            if (href != null) {
              final navPath = '$baseDir$href';
              final navEntry = archive.findFile(navPath);
              if (navEntry != null) {
                final navDoc = xml.XmlDocument.parse(utf8.decode(navEntry.content as List<int>, allowMalformed: true));
                for (final li in _findLocalElements(navDoc, 'li')) {
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

  /// Converts HTML content to rich TextSpan preserving basic formatting.
  TextSpan _htmlToRichContent(String html) {
    // Strip style/script blocks
    var cleaned = html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');

    // Add newlines after block tags
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'</?(p|div|h[1-6]|blockquote|tr|li|br)[^>]*>', caseSensitive: false, dotAll: true),
      (m) => '\n',
    );

    // Parse inline formatting
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    int i = 0;
    bool bold = false;
    bool italic = false;

    void flushText() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(
          text: buffer.toString(),
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontStyle: italic ? FontStyle.italic : null),
        ));
        buffer.clear();
      }
    }

    while (i < cleaned.length) {
      if (cleaned[i] == '<') {
        final closeIdx = cleaned.indexOf('>', i);
        if (closeIdx == -1) {
          buffer.write(cleaned.substring(i));
          break;
        }
        final tag = cleaned.substring(i + 1, closeIdx).trim().toLowerCase();

        if (tag == 'b' || tag == 'strong' || tag == '/b' || tag == '/strong') {
          flushText();
          bold = !tag.startsWith('/');
        } else if (tag == 'i' || tag == 'em' || tag == '/i' || tag == '/em') {
          flushText();
          italic = !tag.startsWith('/');
        }

        i = closeIdx + 1;
      } else {
        if (cleaned[i] == '&') {
          final semi = cleaned.indexOf(';', i);
          if (semi != -1 && semi - i < 10) {
            final entity = cleaned.substring(i, semi + 1);
            final decoded = _decodeHtmlEntity(entity);
            buffer.write(decoded);
            i = semi + 1;
            continue;
          }
        }
        buffer.write(cleaned[i]);
        i++;
      }
    }
    flushText();

    // Collapse excessive whitespace in each span
    for (int j = 0; j < spans.length; j++) {
      final span = spans[j] as TextSpan;
      final text = span.text?.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      if (text != null && text.isNotEmpty) {
        spans[j] = TextSpan(text: text, style: span.style);
      }
    }

    spans.removeWhere((s) => (s as TextSpan).text?.isEmpty ?? true);

    if (spans.isEmpty) return TextSpan(text: _htmlToText(html));
    return TextSpan(children: spans);
  }

  String _decodeHtmlEntity(String entity) {
    return switch (entity) {
      '&amp;' => '&',
      '&lt;' => '<',
      '&gt;' => '>',
      '&quot;' => '"',
      '&apos;' => "'",
      '&nbsp;' => ' ',
      '&#8216;' => '\u2018',
      '&#8217;' => '\u2019',
      '&#8220;' => '\u201C',
      '&#8221;' => '\u201D',
      '&#8212;' => '\u2014',
      '&#8211;' => '\u2013',
      _ => entity,
    };
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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchMatchPositions = [];
        _currentMatchIndex = -1;
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _updateSearch() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _searchMatchPositions = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final content = _chapters[_currentChapterIndex].content;
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final positions = <int>[];
    int start = 0;
    while (true) {
      final idx = lowerContent.indexOf(lowerQuery, start);
      if (idx == -1) break;
      positions.add(idx);
      start = idx + 1;
    }
    setState(() {
      _searchMatchPositions = positions;
      _currentMatchIndex = positions.isEmpty ? -1 : 0;
    });
    if (positions.isNotEmpty) _scrollToMatch(positions[0]);
  }

  void _nextMatch() {
    if (_searchMatchPositions.isEmpty) return;
    final next = (_currentMatchIndex + 1) % _searchMatchPositions.length;
    setState(() => _currentMatchIndex = next);
    _scrollToMatch(_searchMatchPositions[next]);
  }

  void _previousMatch() {
    if (_searchMatchPositions.isEmpty) return;
    final prev = (_currentMatchIndex - 1 + _searchMatchPositions.length) % _searchMatchPositions.length;
    setState(() => _currentMatchIndex = prev);
    _scrollToMatch(_searchMatchPositions[prev]);
  }

  void _scrollToMatch(int charPos) {
    if (!_scrollController.hasClients) return;
    final content = _chapters[_currentChapterIndex].content;
    if (content.isEmpty) return;
    final ratio = charPos / content.length;
    final target = ratio * _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _showThemeSettings() {
    final themeData = [
      {'key': 'original', 'name': 'Original', 'bg': 0xFFFFFFFF, 'text': 0xFF1A1A1A},
      {'key': 'quiet', 'name': 'Quiet', 'bg': 0xFF5A5A5C, 'text': 0xFFE5E5EA},
      {'key': 'paper', 'name': 'Paper', 'bg': 0xFFE8E4F0, 'text': 0xFF6B6380},
      {'key': 'calm', 'name': 'Calm', 'bg': 0xFFF5E4E4, 'text': 0xFF3D2C2C},
      {'key': 'focus', 'name': 'Focus', 'bg': 0xFFF5ECD7, 'text': 0xFF6B6050},
      {'key': 'bold', 'name': 'Bold', 'bg': 0xFFFFFFFF, 'text': 0xFF000000},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF2F1F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Themes & Settings',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'Focus Options',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1C1C1E).withOpacity(0.5),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: const Color(0xFF1C1C1E).withOpacity(0.3),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3E2E6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF8E8E93)),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Font size & page layout controls
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E4EA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                      onTap: () {
                                        setState(() => _fontSize = (_fontSize - 1).clamp(12.0, 28.0));
                                        _saveProgress();
                                        setSheetState(() {});
                                      },
                                      child: const Center(
                                        child: Text(
                                          'A',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 22,
                                    color: const Color(0xFFC7C7CC),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                      onTap: () {
                                        setState(() => _fontSize = (_fontSize + 1).clamp(12.0, 28.0));
                                        _saveProgress();
                                        setSheetState(() {});
                                      },
                                      child: const Center(
                                        child: Text(
                                          'A',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E4EA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                  onTap: () {
                                    setState(() {
                                      _isPageMode = false;
                                    });
                                    _saveProgress();
                                    setSheetState(() {});
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: !_isPageMode ? const Color(0xFF1C1C1E) : Colors.transparent,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                    ),
                                    child: Icon(
                                      Icons.article_rounded,
                                      size: 20,
                                      color: !_isPageMode ? Colors.white : const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 22,
                                  color: const Color(0xFFC7C7CC),
                                ),
                                InkWell(
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                  onTap: () {
                                    setState(() {
                                      _isPageMode = true;
                                      _pageController = PageController(initialPage: _currentChapterIndex);
                                    });
                                    _saveProgress();
                                    setSheetState(() {});
                                  },
                                  child: Container(
                                    width: 48,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _isPageMode ? const Color(0xFF1C1C1E) : Colors.transparent,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                    ),
                                    child: Icon(
                                      Icons.auto_stories_rounded,
                                      size: 20,
                                      color: _isPageMode ? Colors.white : const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Theme grid
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: themeData.map((t) {
                          final key = t['key'] as String;
                          final isActive = _readingTheme == key;
                          final bg = Color(t['bg'] as int);
                          final text = Color(t['text'] as int);
                          return GestureDetector(
                            onTap: () {
                              setState(() => _readingTheme = key);
                              _saveProgress();
                              setSheetState(() {});
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive ? const Color(0xFF007AFF) : const Color(0xFFC7C7CC).withOpacity(0.4),
                                  width: isActive ? 2 : 1,
                                ),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Aa',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: key == 'bold' ? FontWeight.w900 : FontWeight.w400,
                                      color: text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t['name'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: text.withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getThemeIcon() {
    switch (_readingTheme) {
      case 'quiet':
        return Icons.dark_mode_rounded;
      case 'paper':
        return Icons.palette_outlined;
      case 'calm':
        return Icons.wb_sunny_rounded;
      case 'focus':
        return Icons.light_mode_rounded;
      case 'bold':
        return Icons.format_bold_rounded;
      case 'original':
      default:
        return Icons.light_mode_rounded;
    }
  }

  TextSpan _buildHighlightedText(String content, Color textColor) {
    final query = _searchController.text;
    if (query.isEmpty || _searchMatchPositions.isEmpty) {
      return TextSpan(text: content);
    }

    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (int i = 0; i < _searchMatchPositions.length; i++) {
      final matchStart = _searchMatchPositions[i];
      if (matchStart > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, matchStart)));
      }
      final isActive = i == _currentMatchIndex;
      spans.add(TextSpan(
        text: content.substring(matchStart, matchStart + query.length),
        style: TextStyle(
          backgroundColor: isActive ? Colors.orange : Colors.yellow.withOpacity(0.4),
          color: isActive ? Colors.white : textColor,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastEnd = matchStart + query.length;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return TextSpan(children: spans);
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _saveProgress();
    setState(() {
      _currentChapterIndex = index;
      _currentScrollOffset = 0.0;
    });
    if (_isPageMode) {
      _pageController?.jumpToPage(index);
    } else {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
    if (_isSearching) _updateSearch();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (_readingTheme) {
      case 'quiet':
        bgColor = const Color(0xFF3A3A3A);
        textColor = const Color(0xFFC8C8C8);
        break;
      case 'paper':
        bgColor = const Color(0xFFE8E4F0);
        textColor = const Color(0xFF6B6380);
        break;
      case 'calm':
        bgColor = const Color(0xFFF5E4E4);
        textColor = const Color(0xFF3D2C2C);
        break;
      case 'focus':
        bgColor = const Color(0xFFF5ECD7);
        textColor = const Color(0xFF6B6050);
        break;
      case 'bold':
        bgColor = const Color(0xFFFFFFFF);
        textColor = const Color(0xFF000000);
        break;
      case 'original':
      default:
        bgColor = const Color(0xFFFFFFFF);
        textColor = const Color(0xFF1A1A1A);
        break;
    }
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? _buildLoading(bgColor, accentColor)
          : _error != null
              ? _buildError(bgColor, textColor)
              : _buildReader(bgColor, textColor, accentColor),
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

  Widget _buildReader(Color bg, Color textColor, Color accent) {
    final chapter = _chapters[_currentChapterIndex];

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          // Main reading area
          _isPageMode
              ? PageView.builder(
                  controller: _pageController ??= PageController(initialPage: _currentChapterIndex),
                  onPageChanged: (index) {
                    _saveProgress();
                    setState(() {
                      _currentChapterIndex = index;
                      _currentScrollOffset = 0.0;
                    });
                    if (_isSearching) _updateSearch();
                  },
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final ch = _chapters[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 90, bottom: 100, left: 24, right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chapter title
                          Text(
                            ch.title,
                            style: TextStyle(
                              fontSize: _fontSize + 6,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Chapter content
                          SelectableText.rich(
                            _isSearching
                                ? _buildHighlightedText(ch.content, textColor)
                                : ch.richContent,
                            style: TextStyle(
                              fontSize: _fontSize,
                              color: textColor,
                              height: 1.75,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    );
                  },
                )
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 90, bottom: 100),
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
                              SelectableText.rich(
                                _isSearching
                                    ? _buildHighlightedText(chapter.content, textColor)
                                    : chapter.richContent,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.7)),
                            onPressed: widget.onClose,
                            tooltip: 'Back to player',
                          ),
                          Expanded(
                            child: _isSearching
                                ? TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(fontSize: 14, color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'Search...',
                                      hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (_) => _updateSearch(),
                                  )
                                : Text(
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
                          // Auto scroll toggle
                          IconButton(
                            icon: Icon(_isAutoScrolling ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                            color: _isAutoScrolling ? accent : textColor.withOpacity(0.7),
                            onPressed: _toggleAutoScroll,
                            tooltip: _isAutoScrolling ? 'Pause Auto-Scroll' : 'Start Auto-Scroll',
                          ),
                          // Font size controls
                          IconButton(
                            icon: Icon(Icons.text_decrease_rounded, size: 20, color: textColor.withOpacity(0.7)),
                            onPressed: () {
                              setState(() => _fontSize = (_fontSize - 1).clamp(12.0, 28.0));
                              _saveProgress();
                            },
                            tooltip: 'Decrease font size',
                          ),
                          IconButton(
                            icon: Icon(Icons.text_increase_rounded, size: 20, color: textColor.withOpacity(0.7)),
                            onPressed: () {
                              setState(() => _fontSize = (_fontSize + 1).clamp(12.0, 28.0));
                              _saveProgress();
                            },
                            tooltip: 'Increase font size',
                          ),
                          // Theme toggle
                          IconButton(
                            icon: Icon(_getThemeIcon(), size: 20, color: textColor.withOpacity(0.7)),
                            onPressed: _showThemeSettings,
                            tooltip: 'Reading theme',
                          ),
                          // Search button
                          IconButton(
                            icon: Icon(_isSearching ? Icons.search_off_rounded : Icons.search_rounded, size: 20, color: textColor.withOpacity(0.7)),
                            onPressed: _toggleSearch,
                            tooltip: _isSearching ? 'Close search' : 'Search',
                          ),
                          // TOC button
                          IconButton(
                            icon: Icon(Icons.format_list_bulleted_rounded, size: 20, color: textColor.withOpacity(0.7)),
                            onPressed: () => _showToc(context, textColor, bg, accent),
                            tooltip: 'Table of contents',
                          ),
                        ],
                      ),
                    ),
                    if (_isSearching)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: textColor.withOpacity(0.05))),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 14, color: textColor.withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Text(
                              _searchMatchPositions.isEmpty
                                  ? _searchController.text.isEmpty
                                      ? 'Type to search'
                                      : 'No matches'
                                  : '${_currentMatchIndex + 1} of ${_searchMatchPositions.length}',
                              style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
                            ),
                            if (_searchMatchPositions.isNotEmpty) ...[
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                                onPressed: _currentMatchIndex > 0 ? _previousMatch : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: textColor.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                onPressed: _currentMatchIndex < _searchMatchPositions.length - 1 ? _nextMatch : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: textColor.withOpacity(0.6),
                              ),
                            ],
                          ],
                        ),
                      ),
                    // Auto Scroll Speed controller (Only shown when auto scrolling is active or controls are shown)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: textColor.withOpacity(0.05))),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.speed_rounded, size: 16, color: textColor.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Text(
                            'Scroll Speed:',
                            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
                          ),
                          Expanded(
                            child: Slider(
                              value: _autoScrollSpeed,
                              min: 5.0,
                              max: 100.0,
                              activeColor: accent,
                              inactiveColor: accent.withOpacity(0.2),
                              onChanged: (val) {
                                setState(() {
                                  _autoScrollSpeed = val;
                                });
                                if (_isAutoScrolling) {
                                  _startAutoScroll();
                                }
                              },
                            ),
                          ),
                          Text(
                            '${_autoScrollSpeed.round()} px/s',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ],
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
  final String content; // plain text (for search)
  final TextSpan richContent; // rich text (for display)

  const _EpubChapter({
    required this.title,
    required this.content,
    required this.richContent,
  });
}

/// Utility to find an epub file in a given directory path.
Future<String?> findEpubInFolder(String folderPath) async {
  try {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;
    
    await for (final entity in dir.list()) {
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
