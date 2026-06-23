import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'm4b_parser.dart'; // To reuse RandomDataReader, FileRandomDataReader, HttpRandomDataReader

class Mp3Chapter {
  final String title;
  final int startTimeMillis;
  final int durationMillis;

  Mp3Chapter({
    required this.title,
    required this.startTimeMillis,
    required this.durationMillis,
  });

  @override
  String toString() => 'Mp3Chapter(title: $title, start: $startTimeMillis ms, duration: $durationMillis ms)';
}

class Mp3Parser {
  /// Safely decode bytes as ASCII, replacing non-ASCII bytes with '?'
  static String _safeAscii(List<int> bytes) {
    return String.fromCharCodes(bytes.map((b) => (b >= 0x20 && b <= 0x7E) ? b : 0x3F));
  }

  /// Safely decode bytes as UTF-8, falling back to latin1 on error
  static String _safeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static Future<List<Mp3Chapter>> parseChapters(String pathOrUrl) async {
    RandomDataReader? reader;
    try {
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        reader = HttpRandomDataReader(pathOrUrl);
      } else {
        String cleanPath = pathOrUrl.startsWith('file://')
            ? Uri.parse(pathOrUrl).toFilePath()
            : pathOrUrl;
        if (cleanPath.contains('%')) {
          try {
            cleanPath = Uri.decodeComponent(cleanPath);
          } catch (_) {}
        }
        final file = File(cleanPath);
        if (!await file.exists()) return [];
        final raf = await file.open(mode: FileMode.read);
        final len = await file.length();
        reader = FileRandomDataReader(raf, len);
      }

      return await _parse(reader);
    } catch (e) {
      print('[Mp3Parser] Error parsing chapters: $e');
      return [];
    } finally {
      if (reader != null) {
        await reader.close();
      }
    }
  }

  static Future<List<Mp3Chapter>> _parse(RandomDataReader reader) async {
    final length = await reader.length();
    print('[Mp3Parser] Starting ID3 parse on data reader of length $length bytes');
    if (length < 10) {
      print('[Mp3Parser] File too short for ID3');
      return [];
    }

    await reader.setPosition(0);
    final headerBytes = await reader.read(10);
    if (headerBytes.length < 10) {
      print('[Mp3Parser] Failed to read 10 bytes ID3 header');
      return [];
    }

    // Check for "ID3"
    if (headerBytes[0] != 0x49 || headerBytes[1] != 0x44 || headerBytes[2] != 0x33) {
      print('[Mp3Parser] No ID3 header found at offset 0 (bytes: ${headerBytes.sublist(0, 3)})');
      return [];
    }

    final majorVersion = headerBytes[3];
    print('[Mp3Parser] Found ID3v2.$majorVersion tag');
    // We support ID3v2.3 and ID3v2.4
    if (majorVersion != 3 && majorVersion != 4) {
      print('[Mp3Parser] Unsupported ID3 major version: $majorVersion');
      return [];
    }

    // Synchsafe size of ID3 tag (4 bytes, 7 bits per byte)
    final tagSize = ((headerBytes[6] & 0x7F) << 21) |
                    ((headerBytes[7] & 0x7F) << 14) |
                    ((headerBytes[8] & 0x7F) << 7) |
                    (headerBytes[9] & 0x7F);

    print('[Mp3Parser] ID3 tag size: $tagSize bytes');
    if (tagSize <= 0 || tagSize > length) {
      print('[Mp3Parser] Invalid ID3 tag size');
      return [];
    }

    // Read the entire ID3 tag data (excluding the 10-byte header)
    final tagData = await reader.read(tagSize);
    print('[Mp3Parser] Read ${tagData.length} bytes of tag data');
    if (tagData.length < tagSize) return [];

    final List<Mp3Chapter> chapters = [];
    int offset = 0;

    // Parse frames
    while (offset + 10 < tagSize) {
      if (offset + 4 > tagData.length) break;

      // Read frame ID (4 characters) — ASCII only, no named params accepted
      final frameIdBytes = tagData.sublist(offset, offset + 4);
      final frameId = _safeAscii(frameIdBytes).trim();

      // If frame ID is empty or contains non-alphanumeric characters, stop
      if (frameId.isEmpty || !RegExp(r'^[A-Z0-9]{4}$').hasMatch(frameId)) {
        break;
      }

      if (offset + 8 > tagData.length) break;

      // Read frame size
      int frameSize = 0;
      if (majorVersion == 4) {
        // ID3v2.4 uses synchsafe integers for frame sizes
        frameSize = ((tagData[offset + 4] & 0x7F) << 21) |
                    ((tagData[offset + 5] & 0x7F) << 14) |
                    ((tagData[offset + 6] & 0x7F) << 7) |
                    (tagData[offset + 7] & 0x7F);
      } else {
        // ID3v2.3 uses standard big-endian integers
        frameSize = (tagData[offset + 4] << 24) |
                    (tagData[offset + 5] << 16) |
                    (tagData[offset + 6] << 8) |
                    tagData[offset + 7];
      }

      if (frameSize <= 0 || offset + 10 + frameSize > tagSize) {
        break;
      }

      final frameContent = tagData.sublist(offset + 10, offset + 10 + frameSize);

      if (frameId == 'CHAP') {
        final chapter = _parseChapFrame(frameContent);
        if (chapter != null) {
          chapters.add(chapter);
        }
      }

      offset += 10 + frameSize;
    }

    // Sort chapters by start time
    chapters.sort((a, b) => a.startTimeMillis.compareTo(b.startTimeMillis));

    // Calculate durations from gaps between chapters
    final List<Mp3Chapter> finalChapters = [];
    for (int i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      int duration = ch.durationMillis;
      if (duration <= 0) {
        if (i + 1 < chapters.length) {
          duration = chapters[i + 1].startTimeMillis - ch.startTimeMillis;
        } else {
          duration = 0;
        }
      }
      finalChapters.add(Mp3Chapter(
        title: ch.title,
        startTimeMillis: ch.startTimeMillis,
        durationMillis: duration,
      ));
    }

    return finalChapters;
  }

  static Mp3Chapter? _parseChapFrame(List<int> bytes) {
    if (bytes.length < 17) return null;

    int offset = 0;
    // 1. Element ID (null-terminated string)
    final elementIdBytes = <int>[];
    while (offset < bytes.length && bytes[offset] != 0) {
      elementIdBytes.add(bytes[offset]);
      offset++;
    }
    offset++; // skip null byte

    if (offset + 16 > bytes.length) return null;

    // 2. Start time (4 bytes, 32-bit big-endian integer, in milliseconds)
    final startTime = (bytes[offset] << 24) |
                      (bytes[offset + 1] << 16) |
                      (bytes[offset + 2] << 8) |
                      bytes[offset + 3];
    offset += 4;

    // 3. End time (4 bytes)
    final endTime = (bytes[offset] << 24) |
                    (bytes[offset + 1] << 16) |
                    (bytes[offset + 2] << 8) |
                    bytes[offset + 3];
    offset += 4;

    // 4. Skip start byte offset and end byte offset (4 bytes each)
    offset += 8;

    // 5. Sub-frames — find TIT2 for the chapter title
    String title = '';
    while (offset + 10 <= bytes.length) {
      final subFrameId = _safeAscii(bytes.sublist(offset, offset + 4)).trim();
      if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(subFrameId)) {
        break;
      }

      final subFrameSize = (bytes[offset + 4] << 24) |
                           (bytes[offset + 5] << 16) |
                           (bytes[offset + 6] << 8) |
                           bytes[offset + 7];

      if (subFrameSize <= 0 || offset + 10 + subFrameSize > bytes.length) {
        break;
      }

      final subFrameContent = bytes.sublist(offset + 10, offset + 10 + subFrameSize);

      if (subFrameId == 'TIT2') {
        title = _parseTextFrame(subFrameContent);
      }

      offset += 10 + subFrameSize;
    }

    // Fall back to element ID if no TIT2 title found
    if (title.isEmpty) {
      title = _safeAscii(elementIdBytes);
    }

    final duration = (endTime > startTime) ? (endTime - startTime) : 0;

    return Mp3Chapter(
      title: title,
      startTimeMillis: startTime,
      durationMillis: duration,
    );
  }

  static String _parseTextFrame(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final encoding = bytes[0];
    final textBytes = bytes.sublist(1);

    if (encoding == 0x00) {
      // ISO-8859-1 / Latin-1
      return latin1.decode(textBytes).trim();
    } else if (encoding == 0x01) {
      // UTF-16 with BOM
      if (textBytes.length >= 2) {
        final hasLeBom = textBytes[0] == 0xFF && textBytes[1] == 0xFE;
        final hasBeBom = textBytes[0] == 0xFE && textBytes[1] == 0xFF;
        final dataBytes = (hasLeBom || hasBeBom) ? textBytes.sublist(2) : textBytes;
        final list = Uint8List.fromList(dataBytes);
        // Ensure even length for Uint16List
        final paddedList = list.length % 2 == 0 ? list : Uint8List.fromList([...list, 0]);
        final buffer = paddedList.buffer.asUint16List();
        if (hasLeBom || (!hasLeBom && !hasBeBom)) {
          // Little-endian (default or BOM says LE)
          return String.fromCharCodes(buffer).replaceAll('\x00', '').trim();
        } else {
          // Big-endian: swap bytes
          final swapped = Uint16List(buffer.length);
          for (int i = 0; i < buffer.length; i++) {
            final val = buffer[i];
            swapped[i] = ((val & 0xFF) << 8) | ((val >> 8) & 0xFF);
          }
          return String.fromCharCodes(swapped).replaceAll('\x00', '').trim();
        }
      }
      return String.fromCharCodes(textBytes).trim();
    } else if (encoding == 0x02) {
      // UTF-16 Big Endian without BOM
      final list = Uint8List.fromList(textBytes);
      final paddedList = list.length % 2 == 0 ? list : Uint8List.fromList([...list, 0]);
      final buffer = paddedList.buffer.asUint16List();
      final swapped = Uint16List(buffer.length);
      for (int i = 0; i < buffer.length; i++) {
        final val = buffer[i];
        swapped[i] = ((val & 0xFF) << 8) | ((val >> 8) & 0xFF);
      }
      return String.fromCharCodes(swapped).replaceAll('\x00', '').trim();
    } else if (encoding == 0x03) {
      // UTF-8
      return _safeUtf8(textBytes).trim();
    }

    // Unknown encoding — try UTF-8 with latin1 fallback
    return _safeUtf8(textBytes).trim();
  }
}
