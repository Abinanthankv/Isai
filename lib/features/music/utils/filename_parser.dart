/// Cleanly parsed (artist, title) pair for an audio file name.
class ParsedFileName {
  const ParsedFileName({required this.title, required this.artist});

  final String title;
  final String artist;
}

/// Release-noise tags (years, format, quality, editions) that TorBox torrents
/// commonly append to track names. Kept in a compiled regex for speed.
final RegExp _releaseNoisePattern = RegExp(
  r'\b(?:'
  r'flac|mp3|wav|aac|alac|aiff|ogg|opus|webm|m4a|webrip|hdtracks|dsd|vorbis'
  r'|hi[- ]?res|lossless|losless'
  r'|\d{1,3}\s*(?:bit|kbps|khz)'
  r'|320|256|192|128'
  r'|remaster\w*|deluxe|expanded|bonus|special|limited|anniversary|reissue|collector'
  r'|edition|album\s*version|album\s*edit|radio\s*edit|single\s*version'
  r'|instrumental|acoustic|explicit|clean|official|lyric\s*video|music\s*video'
  r'|cinematic|original\s*score|score|original\s*soundtrack|soundtrack'
  r'|motion\s*picture\s*(?:soundtrack|score)|ost'
  r'|vinyl|cd|disc\s*\d'
  r'|web'
  r')\b',
  caseSensitive: false,
);

/// Returns true when a `(...)` group is purely a year or a known release tag
/// (FLAC, WEB, Deluxe Edition, 2024, etc.) and should not be part of the title.
bool _isReleaseNoise(String inner) {
  final trimmed = inner.trim();
  final lower = trimmed.toLowerCase();

  // "feat." / "featuring" / "ft." groups carry real artist info — keep them.
  if (lower.contains('feat') ||
      lower.contains('featuring') ||
      lower.contains('ft.')) {
    return false;
  }
  // "(Live ...)" is a real distinguishing part of a track — keep it so we
  // don't silently match the studio version.
  if (lower.contains('live')) return false;

  // Pure year or year range: "2024", "1994", "2010-2011".
  if (RegExp(
    r'^(?:19|20)\d{2}(?:\s*[-–—]\s*(?:19|20)\d{2})?$',
  ).hasMatch(trimmed)) {
    return true;
  }

  return _releaseNoisePattern.hasMatch(lower);
}

String _stripReleaseNoise(String name) {
  var result = name;

  // Square-bracket groups are release/format tags: [FLAC], [WEB], [2024]...
  result = result.replaceAll(RegExp(r'\s*\[[^\[\]]*\]'), '');

  // Parenthetical groups that are years or known release tags.
  result = result.replaceAllMapped(
    RegExp(r'\s*\(([^()]*)\)'),
    (m) => _isReleaseNoise(m.group(1)!) ? '' : m.group(0)!,
  );

  // Strip any standalone year token, wherever it appears (also inside
  // otherwise-kept groups like "(Live at Wembley 1988)").
  final anyYear = RegExp(r'(?:\s|^)(?:19|20)\d{2}(?=\s|$|[)\]])');
  for (var i = 0; i < 3; i++) {
    final before = result;
    result = result.replaceAll(anyYear, '');
    if (result == before) break;
  }

  // Bare trailing tags: "Song 24bit", "Song FLAC", "Song 320kbps",
  // "Song Remaster", "Song Deluxe Edition", ...
  final trailing = RegExp(
    r'\s+(?:flac|mp3|wav|aac|alac|aiff|ogg|opus|webm|m4a'
    r'|web|webrip|hdtracks|dsd|vorbis|hi[- ]?res|lossless'
    r'|remaster\w*|deluxe\s*edition|expanded\s*edition|bonus\s*track'
    r'|\d{1,3}\s*(?:bit|kbps|khz)|320|256|192|128)\s*$',
    caseSensitive: false,
  );
  for (var i = 0; i < 3; i++) {
    final before = result;
    result = result.replaceAll(trailing, '');
    if (result == before) break;
  }

  return result;
}

/// Parses a raw audio filename like `"Artist - Title.flac"` into clean
/// `(artist, title)` pairs, stripping release noise (years, format/quality
/// tags, editions, track numbers) that TorBox torrent names commonly include.
ParsedFileName parseFilename(String displayName) {
  // 1. Strip file extension.
  var name = displayName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();

  // 2. Strip leading track/index numbers: "01 - ", "01. ", "1-", "Disc 1 - ".
  name = name.replaceAll(
    RegExp(r'^(?:\d{1,3}\s*[-.)]?\s*|disc\s*\d+\s*[-.]?\s*)', caseSensitive: false),
    '',
  );

  // 3. Drop release noise: [FLAC], (2024), (Deluxe Edition), trailing tags.
  name = _stripReleaseNoise(name);

  // 4. Drop trailing release markers like " - Single" / " - EP".
  name = name.replaceAll(
    RegExp(r'\s*[-–—]\s*(?:single|ep|lp)\s*$', caseSensitive: false),
    '',
  );

  // 5. Collapse whitespace and remove any dangling separators.
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  name = name.replaceAll(RegExp(r'^\s*[-–—]\s*'), '').trim();
  name = name.replaceAll(RegExp(r'\s*[-–—]\s*$'), '').trim();

  // 6. Split "Artist - Title" on the first separator.
  final sep = RegExp(r' [-–—] ');
  final match = sep.firstMatch(name);
  if (match != null) {
    var title = name.substring(match.end).trim();
    // Handle a leftover track number right after the artist (rarer layouts).
    title = title.replaceAll(RegExp(r'^\d{1,3}\s*[-.)]?\s*'), '').trim();
    return ParsedFileName(
      artist: name.substring(0, match.start).trim(),
      title: title,
    );
  }
  return ParsedFileName(title: name.trim(), artist: '');
}