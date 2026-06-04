import 'dart:convert';

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});

  @override
  String toString() => '${timestamp.inMilliseconds}: $text';
}

class LyricsData {
  final String? plainLyrics;
  final List<LyricLine> syncedLines;
  final String? source;

  LyricsData({
    this.plainLyrics,
    this.syncedLines = const [],
    this.source,
  });

  bool get hasSynced => syncedLines.isNotEmpty;

  factory LyricsData.fromLrc(String lrc, {String? source}) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)');

    for (final line in lrc.split('\n')) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();

        final duration = Duration(
          minutes: minutes,
          milliseconds: (seconds * 1000).toInt(),
        );

        lines.add(LyricLine(timestamp: duration, text: text));
      }
    }

    return LyricsData(
      syncedLines: lines,
      plainLyrics: lines.map((l) => l.text).join('\n'),
      source: source,
    );
  }
}
