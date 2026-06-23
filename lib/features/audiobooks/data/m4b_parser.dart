import 'dart:io';
import 'dart:typed_data';

class M4bChapter {
  final String title;
  final int startTimeMillis;
  final int durationMillis;

  M4bChapter({
    required this.title,
    required this.startTimeMillis,
    required this.durationMillis,
  });

  @override
  String toString() => 'M4bChapter(title: $title, start: $startTimeMillis ms, duration: $durationMillis ms)';
}

abstract class RandomDataReader {
  Future<int> length();
  Future<void> setPosition(int position);
  Future<List<int>> read(int bytes);
  Future<void> close();
}

class FileRandomDataReader implements RandomDataReader {
  final RandomAccessFile raf;
  final int _length;
  FileRandomDataReader(this.raf, this._length);

  @override
  Future<int> length() async => _length;

  @override
  Future<void> setPosition(int position) async => await raf.setPosition(position);

  @override
  Future<List<int>> read(int bytes) async => await raf.read(bytes);

  @override
  Future<void> close() async => await raf.close();
}

class HttpRandomDataReader implements RandomDataReader {
  final String url;
  int _position = 0;
  int? _length;
  final HttpClient _client = HttpClient();

  // 128 KB buffer cache to prevent making separate HTTP requests for small reads (like box headers)
  Uint8List? _buffer;
  int _bufferOffset = -1;

  HttpRandomDataReader(this.url);

  @override
  Future<int> length() async {
    if (_length != null) return _length!;
    try {
      final uri = Uri.parse(url);
      final request = await _client.headUrl(uri);
      final response = await request.close();
      _length = response.contentLength;
      
      if (_length == null || _length == -1) {
        // Fallback: try GET with Range: bytes=0-0
        final getReq = await _client.getUrl(uri);
        getReq.headers.add('Range', 'bytes=0-0');
        final getRes = await getReq.close();
        final contentRange = getRes.headers.value('content-range');
        if (contentRange != null) {
          final totalStr = contentRange.split('/').last;
          _length = int.tryParse(totalStr);
        }
      }
    } catch (e) {
      print('[HttpRandomDataReader] Head request failed: $e');
    }
    return _length ?? 0;
  }

  @override
  Future<void> setPosition(int position) async {
    _position = position;
  }

  @override
  Future<List<int>> read(int bytes) async {
    if (bytes <= 0) return [];

    final totalSize = await length();
    if (_position >= totalSize) return [];

    // Return data from buffer if it is cached
    if (_buffer != null &&
        _position >= _bufferOffset &&
        _position + bytes <= _bufferOffset + _buffer!.length) {
      final start = _position - _bufferOffset;
      final result = _buffer!.sublist(start, start + bytes);
      _position += bytes;
      return result;
    }

    // Fetch chunk of 128KB to buffer requests
    final fetchSize = bytes > 128 * 1024 ? bytes : 128 * 1024;
    final endPos = (_position + fetchSize - 1).clamp(0, totalSize - 1);

    try {
      final request = await _client.getUrl(Uri.parse(url));
      request.headers.add('Range', 'bytes=$_position-$endPos');
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<int> fetchedData = [];
        await for (final chunk in response) {
          fetchedData.addAll(chunk);
        }
        
        _buffer = Uint8List.fromList(fetchedData);
        _bufferOffset = _position;

        final readBytes = bytes < _buffer!.length ? bytes : _buffer!.length;
        final result = _buffer!.sublist(0, readBytes);
        _position += readBytes;
        return result;
      }
    } catch (e) {
      print('[HttpRandomDataReader] Range fetch error: $e');
    }
    return [];
  }

  @override
  Future<void> close() async {
    _client.close();
  }
}

class M4bParser {
  /// Parses the chapter list from an `.m4b` or `.m4a` file (local path or remote HTTP URL).
  static Future<List<M4bChapter>> parseChapters(String filePathOrUrl) async {
    RandomDataReader? reader;
    try {
      print('[M4bParser] Starting parseChapters for: $filePathOrUrl');
      if (filePathOrUrl.startsWith('http://') || filePathOrUrl.startsWith('https://')) {
        reader = HttpRandomDataReader(filePathOrUrl);
      } else {
        String cleanPath = filePathOrUrl.startsWith('file://')
            ? Uri.parse(filePathOrUrl).toFilePath()
            : filePathOrUrl;
        if (cleanPath.contains('%')) {
          try {
            cleanPath = Uri.decodeComponent(cleanPath);
          } catch (_) {}
        }
        final file = File(cleanPath);
        if (!await file.exists()) {
          print('[M4bParser] File does not exist at: $cleanPath');
          return [];
        }
        final raf = await file.open(mode: FileMode.read);
        final size = await file.length();
        reader = FileRandomDataReader(raf, size);
      }

      final fileSize = await reader.length();
      print('[M4bParser] File size resolved: $fileSize bytes');
      if (fileSize <= 0) return [];
      
      final List<M4bChapter> chapters = [];

      // 1. Try parsing Apple 'chpl' box (fast scan)
      print('[M4bParser] Scanning for chpl box...');
      await _parseChplBoxRecursive(reader, 0, fileSize, chapters);
      print('[M4bParser] chpl scan returned ${chapters.length} chapters');

      // 2. If no chapters found via 'chpl', parse text chapter tracks
      if (chapters.isEmpty) {
        print('[M4bParser] chpl was empty, parsing text tracks...');
        final List<TrackInfo> tracks = [];
        await _parseTracks(reader, 0, fileSize, tracks);
        print('[M4bParser] Found ${tracks.length} tracks total');
        
        for (int i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          print('[M4bParser] Track $i: handlerType=${track.handlerType}, handlerSubtype=${track.handlerSubtype}');
          if (track.handlerType == 'text' || 
              track.handlerSubtype == 'text' || 
              track.handlerType == 'sbtl' || 
              track.handlerSubtype == 'sbtl') {
            print('[M4bParser] Decoding text track sample data...');
            final textChapters = await _decodeTextTrack(reader, track);
            print('[M4bParser] Decoded ${textChapters.length} chapters from text track');
            if (textChapters.isNotEmpty) {
              chapters.addAll(textChapters);
              break; // Found the chapter track
            }
          }
        }
      }

      // Calculate chapter durations based on the next chapter's start time
      if (chapters.isNotEmpty) {
        for (int i = 0; i < chapters.length - 1; i++) {
          final current = chapters[i];
          final next = chapters[i + 1];
          final duration = next.startTimeMillis - current.startTimeMillis;
          chapters[i] = M4bChapter(
            title: current.title,
            startTimeMillis: current.startTimeMillis,
            durationMillis: duration > 0 ? duration : 0,
          );
        }
      }

      return chapters;
    } catch (e) {
      print('[M4bParser] Error parsing M4B chapters: $e');
      return [];
    } finally {
      await reader?.close();
    }
  }

  // ─── Apple 'chpl' Box Parser ───────────────────────────────────

  static Future<void> _parseChplBoxRecursive(
    RandomDataReader reader,
    int offset,
    int endOffset,
    List<M4bChapter> chapters,
  ) async {
    int currentOffset = offset;
    int localIterations = 0;

    while (currentOffset < endOffset) {
      localIterations++;
      if (localIterations > 500) {
        print('[M4bParser] Aborting _parseChplBoxRecursive: too many iterations ($localIterations) at offset $currentOffset');
        break;
      }
      if (currentOffset + 8 > endOffset) break;
      await reader.setPosition(currentOffset);

      final sizeBytes = await reader.read(4);
      if (sizeBytes.length < 4) break;
      final typeBytes = await reader.read(4);
      if (typeBytes.length < 4) break;

      final bd = ByteData.sublistView(Uint8List.fromList(sizeBytes));
      int boxSize = bd.getUint32(0);
      final boxType = String.fromCharCodes(typeBytes);

      int headerSize = 8;
      if (boxSize == 1) {
        if (currentOffset + 16 > endOffset) break;
        final largeSizeBytes = await reader.read(8);
        final lbd = ByteData.sublistView(Uint8List.fromList(largeSizeBytes));
        boxSize = lbd.getUint64(0);
        headerSize = 16;
      }

      if (boxSize <= 0) break;

      final contentOffset = currentOffset + headerSize;
      final contentSize = boxSize - headerSize;

      if (boxType == 'moov' || 
          boxType == 'udta' || 
          boxType == 'trak' || 
          boxType == 'mdia' || 
          boxType == 'minf' || 
          boxType == 'stbl') {
        await _parseChplBoxRecursive(reader, contentOffset, contentOffset + contentSize, chapters);
        if (chapters.isNotEmpty && (boxType == 'udta' || boxType == 'moov')) {
          return;
        }
      } else if (boxType == 'chpl') {
        await _decodeChplBox(reader, contentOffset, contentSize, chapters);
        return;
      }

      currentOffset += boxSize;
    }
  }

  static Future<void> _decodeChplBox(
    RandomDataReader reader,
    int offset,
    int size,
    List<M4bChapter> chapters,
  ) async {
    await reader.setPosition(offset);
    final versionBytes = await reader.read(1);
    if (versionBytes.isEmpty) return;
    final version = versionBytes[0];

    await reader.setPosition(offset + 4);

    if (version == 1) {
      await reader.read(1); // skip reserved
      final countBytes = await reader.read(4);
      if (countBytes.length < 4) return;
      final cbd = ByteData.sublistView(Uint8List.fromList(countBytes));
      final entryCount = cbd.getUint32(0);

      for (int i = 0; i < entryCount; i++) {
        final timeBytes = await reader.read(8);
        if (timeBytes.length < 8) break;
        final tbd = ByteData.sublistView(Uint8List.fromList(timeBytes));
        final rawTime = tbd.getUint64(0);
        final startTimeMillis = rawTime ~/ 10000;

        final lenBytes = await reader.read(1);
        if (lenBytes.isEmpty) break;
        final titleLen = lenBytes[0];

        final titleBytes = await reader.read(titleLen);
        final title = String.fromCharCodes(titleBytes);

        chapters.add(M4bChapter(
          title: title.trim().isNotEmpty ? title : 'Chapter ${i + 1}',
          startTimeMillis: startTimeMillis,
          durationMillis: 0,
        ));
      }
    } else if (version == 0) {
      final countBytes = await reader.read(4);
      if (countBytes.length < 4) return;
      final cbd = ByteData.sublistView(Uint8List.fromList(countBytes));
      final entryCount = cbd.getUint32(0);

      for (int i = 0; i < entryCount; i++) {
        final timeBytes = await reader.read(8);
        if (timeBytes.length < 8) break;
        final tbd = ByteData.sublistView(Uint8List.fromList(timeBytes));
        final rawTime = tbd.getUint64(0);
        final startTimeMillis = rawTime ~/ 10000;

        final lenBytes = await reader.read(1);
        if (lenBytes.isEmpty) break;
        final titleLen = lenBytes[0];

        final titleBytes = await reader.read(titleLen);
        final title = String.fromCharCodes(titleBytes);

        chapters.add(M4bChapter(
          title: title.trim().isNotEmpty ? title : 'Chapter ${i + 1}',
          startTimeMillis: startTimeMillis,
          durationMillis: 0,
        ));
      }
    }
  }

  // ─── Nero/QuickTime Text Track Parser ──────────────────────────

  static Future<void> _parseTracks(
    RandomDataReader reader,
    int offset,
    int endOffset,
    List<TrackInfo> tracks,
  ) async {
    int currentOffset = offset;
    int localIterations = 0;

    while (currentOffset < endOffset) {
      localIterations++;
      if (localIterations > 500) {
        print('[M4bParser] Aborting _parseTracks: too many iterations ($localIterations) at offset $currentOffset');
        break;
      }
      if (currentOffset + 8 > endOffset) break;
      await reader.setPosition(currentOffset);

      final sizeBytes = await reader.read(4);
      if (sizeBytes.length < 4) break;
      final typeBytes = await reader.read(4);
      if (typeBytes.length < 4) break;

      final bd = ByteData.sublistView(Uint8List.fromList(sizeBytes));
      int boxSize = bd.getUint32(0);
      final boxType = String.fromCharCodes(typeBytes);

      int headerSize = 8;
      if (boxSize == 1) {
        if (currentOffset + 16 > endOffset) break;
        final largeSizeBytes = await reader.read(8);
        final lbd = ByteData.sublistView(Uint8List.fromList(largeSizeBytes));
        boxSize = lbd.getUint64(0);
        headerSize = 16;
      }

      if (boxSize <= 0) break;

      final contentOffset = currentOffset + headerSize;
      final contentSize = boxSize - headerSize;

      if (boxType == 'trak') {
        tracks.add(TrackInfo());
        await _parseTracks(reader, contentOffset, contentOffset + contentSize, tracks);
      } else if (boxType == 'tkhd') {
        await reader.setPosition(contentOffset);
        final versionBytes = await reader.read(1);
        final version = versionBytes.isNotEmpty ? versionBytes[0] : 0;
        await reader.setPosition(contentOffset + (version == 1 ? 16 : 12));
        final idBytes = await reader.read(4);
        if (idBytes.length == 4 && tracks.isNotEmpty) {
          final ibd = ByteData.sublistView(Uint8List.fromList(idBytes));
          tracks.last.trackId = ibd.getUint32(0);
        }
      } else if (boxType == 'mdhd') {
        await reader.setPosition(contentOffset);
        final versionBytes = await reader.read(1);
        final version = versionBytes.isNotEmpty ? versionBytes[0] : 0;
        await reader.setPosition(contentOffset + (version == 1 ? 20 : 12));
        final timescaleBytes = await reader.read(4);
        if (timescaleBytes.length == 4 && tracks.isNotEmpty) {
          final tbd = ByteData.sublistView(Uint8List.fromList(timescaleBytes));
          tracks.last.mediaTimescale = tbd.getUint32(0);
        }
      } else if (boxType == 'hdlr') {
        await reader.setPosition(contentOffset + 8); // Skip version & flags & predefined
        final handlerBytes = await reader.read(4);
        if (handlerBytes.length == 4 && tracks.isNotEmpty) {
          tracks.last.handlerType = String.fromCharCodes(handlerBytes);
        }
        final subtypeBytes = await reader.read(4);
        if (subtypeBytes.length == 4 && tracks.isNotEmpty) {
          tracks.last.handlerSubtype = String.fromCharCodes(subtypeBytes);
        }
      } else if (boxType == 'stco') {
        await reader.setPosition(contentOffset + 4); // skip version & flags
        final countBytes = await reader.read(4);
        if (countBytes.length == 4 && tracks.isNotEmpty) {
          final cbd = ByteData.sublistView(Uint8List.fromList(countBytes));
          int entryCount = cbd.getUint32(0);
          final maxEntries = (contentSize - 8) ~/ 4;
          if (entryCount > maxEntries) {
            entryCount = maxEntries;
          }
          if (entryCount > 5000) {
            entryCount = 5000;
          }
          if (entryCount > 0) {
            final List<int> offsets = [];
            for (int i = 0; i < entryCount; i++) {
              final offBytes = await reader.read(4);
              if (offBytes.length < 4) break;
              final obd = ByteData.sublistView(Uint8List.fromList(offBytes));
              offsets.add(obd.getUint32(0));
            }
            tracks.last.stcoOffsets = offsets;
          }
        }
      } else if (boxType == 'stsz') {
        await reader.setPosition(contentOffset + 4); // skip version & flags
        final sizeBytes = await reader.read(4);
        final countBytes = await reader.read(4);
        if (sizeBytes.length == 4 && countBytes.length == 4 && tracks.isNotEmpty) {
          final sbd = ByteData.sublistView(Uint8List.fromList(sizeBytes));
          final defaultSize = sbd.getUint32(0);
          final cbd = ByteData.sublistView(Uint8List.fromList(countBytes));
          int sampleCount = cbd.getUint32(0);
          final maxSamples = (contentSize - 12) ~/ 4;
          if (sampleCount > maxSamples) {
            sampleCount = maxSamples;
          }
          if (sampleCount > 5000) {
            sampleCount = 5000;
          }
          if (defaultSize > 0) {
            tracks.last.sampleSizes = List.filled(sampleCount, defaultSize);
          } else if (sampleCount > 0) {
            final List<int> sizes = [];
            for (int i = 0; i < sampleCount; i++) {
              final szBytes = await reader.read(4);
              if (szBytes.length < 4) break;
              final szbd = ByteData.sublistView(Uint8List.fromList(szBytes));
              sizes.add(szbd.getUint32(0));
            }
            tracks.last.sampleSizes = sizes;
          }
        }
      } else if (boxType == 'stts') {
        await reader.setPosition(contentOffset + 4); // skip version & flags
        final countBytes = await reader.read(4);
        if (countBytes.length == 4 && tracks.isNotEmpty) {
          final cbd = ByteData.sublistView(Uint8List.fromList(countBytes));
          int entryCount = cbd.getUint32(0);
          final maxEntries = (contentSize - 8) ~/ 8;
          if (entryCount > maxEntries) {
            entryCount = maxEntries;
          }
          if (entryCount > 5000) {
            entryCount = 5000;
          }
          if (entryCount > 0) {
            final List<SttsEntry> entries = [];
            for (int i = 0; i < entryCount; i++) {
              final countValBytes = await reader.read(4);
              final deltaValBytes = await reader.read(4);
              if (countValBytes.length < 4 || deltaValBytes.length < 4) break;
              final cbd = ByteData.sublistView(Uint8List.fromList(countValBytes));
              final dbd = ByteData.sublistView(Uint8List.fromList(deltaValBytes));
              entries.add(SttsEntry(cbd.getUint32(0), dbd.getUint32(0)));
            }
            tracks.last.sttsEntries = entries;
          }
        }
      } else if (boxType == 'moov' || 
                 boxType == 'udta' || 
                 boxType == 'mdia' || 
                 boxType == 'minf' || 
                 boxType == 'stbl') {
        await _parseTracks(reader, contentOffset, contentOffset + contentSize, tracks);
      }

      currentOffset += boxSize;
    }
  }

  static Future<List<M4bChapter>> _decodeTextTrack(RandomDataReader reader, TrackInfo track) async {
    final List<M4bChapter> chapters = [];
    if (track.stcoOffsets.isEmpty || track.sampleSizes.isEmpty) return [];

    final List<int> sampleTimes = [];
    int currentTime = 0;
    for (final entry in track.sttsEntries) {
      for (int i = 0; i < entry.count; i++) {
        sampleTimes.add(currentTime);
        currentTime += entry.delta;
      }
    }
    sampleTimes.add(currentTime);

    final count = track.stcoOffsets.length;
    for (int i = 0; i < count; i++) {
      final offset = track.stcoOffsets[i];
      final size = track.sampleSizes[i];
      if (i >= sampleTimes.length - 1) break;

      final startTimeMillis = (sampleTimes[i] * 1000) ~/ track.mediaTimescale;
      final durationMillis = ((sampleTimes[i + 1] - sampleTimes[i]) * 1000) ~/ track.mediaTimescale;

      await reader.setPosition(offset);
      final data = await reader.read(size);

      String title = '';
      if (data.length >= 2) {
        final bd = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 2)));
        final textLen = bd.getUint16(0);
        if (textLen > 0 && textLen <= data.length - 2) {
          title = String.fromCharCodes(data.sublist(2, 2 + textLen));
        } else {
          title = String.fromCharCodes(data).trim();
        }
      } else {
        title = String.fromCharCodes(data).trim();
      }

      title = title.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();

      chapters.add(M4bChapter(
        title: title.isNotEmpty ? title : 'Chapter ${i + 1}',
        startTimeMillis: startTimeMillis,
        durationMillis: durationMillis,
      ));
    }

    return chapters;
  }
}

class SttsEntry {
  final int count;
  final int delta;
  SttsEntry(this.count, this.delta);
}

class TrackInfo {
  int trackId = 0;
  String handlerType = '';
  String handlerSubtype = '';
  int mediaTimescale = 1;
  List<int> stcoOffsets = [];
  List<int> sampleSizes = [];
  List<SttsEntry> sttsEntries = [];
}
