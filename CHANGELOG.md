# Changelog

## [1.0.10] - July 2026

### Added
- **Next Up Preview**: Shows upcoming tracks as a horizontal scrollable list below the Now Playing controls. Collapsible with arrow toggle. Tap any track to skip to it. Customize in Player Customization — enable/disable, set count (0–10), and choose display style (Art + Name, Art Only, or Name Only).
- **Lyrics Sync Offset Drag**: Long-press and drag vertically on synced lyrics to fine-tune timing — 1px = 50ms. Overlay shows the current offset.
- **Font Style for Lyrics**: Player Customization now has Normal, Bold, Italic, and Bold Italic options for lyrics text, persisted across sessions.

### Changed
- **Artist Screen Redesign**: Section headers with icons + dividers, track numbers on popular songs, enlarged artwork, gradient overlays on albums, Deezer playlist cards in mixed sizes, expandable About section with icon rows and tag chips, enlarged similar artist circles (120px), and DOB with age calculation.
- **Now Playing Wide Screen**: Artwork vertically centered and capped at 65% of screen height, controls centered on the right side, lyrics mode with close button and mini transport bar.
- **Mood Details**: Songs now play directly instead of navigating to the search screen, with a loading spinner while resolving.
- **Responsive Grids**: Library, Playlists, Search, and Category Detail screens now use adaptive column counts (2–6 columns) based on screen width.
- **Search Fallback**: When iTunes returns fewer than 5 results, Deezer is used as a fuzzy/typo-tolerant fallback.
- **Canvas Minimized**: Dark overlay removed when canvas is fullscreen, so the video is fully visible.

### Fixed
- **Lyrics Word Clipping**: Removed `softWrap: false` from letter-by-letter lyrics rendering so the last word is no longer hidden.
- **withOpacity Deprecation**: Replaced all deprecated `withOpacity()` calls with `withValues(alpha:)` across Artist and Now Playing screens.
- **Undefined Color Errors**: Fixed `Colors.black06` / `Colors.black08` references that caused build failures.

## [1.0.9] - July 2026

### Added
- **Apple Music-Style Synced Lyrics**: Active lyric line renders as individual animated words with continuous glow transition — 150ms pre-glow fade-in, hold at full brightness, 600ms fade-out via `Color.lerp` per word.
- **Last.fm Station Playlists on For You Page**: Recommended for You and Your Last.fm Mix sections now appear below top artists. Each fetches 3 pages from Last.fm's internal player API, enriched with iTunes artwork, displayed as gradient playlist cards (tap to open full track list).
- **Long-Press Context Menu**: Discover and For You tracks now support long-press to show Play Next, Add to Queue, Add to Playlist, and Download options via `TrackActionSheet`.
- **Haptic Feedback on Interactions**: Light impact on track taps, medium impact on long-press context menu triggers.
- **KPoe Word-Synced Lyrics Scraper**: New scraper with BiniLyrics cache for synced lyric matching and timing.
- **YouTube Playlist Continuation Pagination**: Playlist imports now paginate beyond the initial 200-track cap using continuation tokens.

### Changed
- **Spotify Canvas Resolution**: Replaced broken ISRC→MusicBrainz→Spotify URL pipeline with search engine scraping (Brave Search + DuckDuckGo) to find track IDs and resolve via canvasdownloader.com. Old ISRC methods preserved as fallback.

### Fixed
- **Lyrics Flicker Eliminated**: Removed `TweenAnimationBuilder` from lyrics — `AudioService.position` stream rebuilds are smooth enough; the tween was resetting on every frame and causing visible flicker.
- **Fresh & Different Missing Artwork**: Tracks from Last.fm similar tracks API with empty `artworkUrl` now fall back to iTunes metadata lookup in parallel.
- **YouTube Pagination for New Format**: Fixed handling of YouTube's new `continuationItemViewModel` format for playlist loading.
- **Continuation Token Parsing**: Switched from hardcoded path to recursive JSON search for YouTube continuation tokens.

## [1.0.8] - July 2026

### Added
- **Player Customization Screen**: New button style selector (Follow App Theme / Apple Music pink accent), toggle individual icons in minimalist layout (Source, Lyrics, Sleep Timer, Up Next Queue).
- **Auto-Play from Scrapers**: Tapping Global Hot Tracks / Trending songs on Discover or For You pages now auto-resolves via installed addons and plays directly — source picker only shown if no addon finds a result.
- **Queue Song Removal**: Remove individual songs from the Now Playing queue via the close button.
- **Built-in Scraper Toggles**: Enable/disable individual built-in scrapers from the Addon Manager.
- **Lyrics.ovh Provider**: Replaced dead Unison lyrics provider with lyrics.ovh free API.

### Changed
- **Now Playing UI**: Redesigned layout with full-screen lyrics toggle, redesigned transport controls (Apple Music-style play/pause, fast-forward/rewind icons), and configurable minimalist icon set.
- **Metadata Fix Reliability**: Fixed metadata now immediately reflects in the Now Playing screen for both library and playlist tracks by passing data directly to the audio handler instead of re-reading from DB.
- **Miniplayer Next Button**: Fixed blocking GestureDetector that prevented skip button from working; restored missing `skipToNext()` call for music tracks.
- **Moved YouTube scraper to last**: Addons are now searched before YouTube, matching user priority from Addon Manager.
- **Removed built-in scrapers (except YouTube)**: Decluttered default scraper list; remaining scrapers managed via Addon Manager.

### Fixed
- **Metadata Overwrite in enrichTrack**: iTunes results no longer overwrite existing correct artist/title/artwork — only used to fill missing genre/album.
- **Miniplayer Next Button**: Two bugs fixed — wrapping GestureDetector blocking taps and missing `skipToNext()` call.
- **Metadata Changes Not Reflecting**: Race condition between Riverpod listener and DB re-read eliminated by passing metadata directly to `customAction('refresh_metadata')`.
- **Addon Search Order**: Addons now take priority over YouTube in search results.

## [1.0.7] - July 2026

### Added
- **For You Page Diversity**: New discovery sections — Outside Your Bubble (under-listened genres) and Fresh & Different (Last.fm similar artists) — with cross-mix deduplication, max 2 per artist, and genre rotation.
- **Discovery Rate Card**: Insights screen now shows a weekly discovery rate, 8-week bar chart, recently-discovered artist chips, and lifetime discovery totals — all from local playback history.
- **Last.fm Scrobble Settings**: Dedicated settings screen with scrobble enable toggle, scrobble threshold slider (25–100%), minimum track length slider (0–10 min), and account info with disconnect.
- **Visualizer Overhaul**: Spectral flux beat detection (kicks/snares across full spectrum), auto-gain normalization, frequency-reactive per-bar colors (rainbow from bass→treble), and a new Circular style.
- **Lyrics.ovh Fallback**: Replaced dead Unison lyrics provider with lyrics.ovh free API — no auth, no Cloudflare blocking.

### Fixed & Improved
- **Visualizer Frequency Mapping**: Equal-band distribution across all FFT bins with quadratic gain ramp so all bars show visible activity instead of just the first few.
- **Beat Detection Accuracy**: Replaced simple bass-energy threshold with spectral flux (positive frame-to-frame energy deltas) with adaptive thresholding.
- **Auto-Gain Feedback Loop**: Normalized FFT stored in a separate list to prevent corrupting the exponential smoothing pipeline.
- **Seek/Play Race Condition**: Fixed addon audio starting from position 0 when toggling video off — `audioHandler.seek()` is now properly awaited before `play()`.
- **Switch Contrast Fixes**: Removed `activeColor: primary` overrides from Switch widgets (Last.fm settings, plugin manager) that made toggles invisible.
- **Slider Reactivity**: Last.fm threshold sliders now use local state for instant visual response; SharedPreferences write deferred to `onChangeEnd`.
- **InteractiveControls Colors**: Reverted unintended white color overrides back to M3 scheme-aware colors.

## [1.0.6] - July 2026

### Added
- **Podcast Continue Listening**: Episode progress now persists after stopping. Multiple in-progress episodes are tracked and shown in the discover screen with resume playback.
- **Podcast Stop Button**: Mini player replaces the next-track button with a stop button for podcasts.
- **Podcast Redirect Resolution**: Audio URLs with tracking redirect chains (e.g., pscrb.fm) are resolved upfront to prevent playback timeouts.
- **Multi-Episode Tracking**: Continue Listening section now shows all in-progress podcast episodes, not just the last played one.
- **Spotify Podcast Charts**: Added Top Podcasts and Top Episodes sections for US and India, sourced from Spotify's podcast charts API.
- **Keyboard Navigation**: Horizontal podcast rows now support left/right arrow key navigation on desktop (Linux/Windows).
- **Responsive Genre Grid**: Genre show-more screen adapts columns to screen width using max-cross-axis-extent layout.
- **Remove from Continue Listening**: Long-press any continue-listening card to remove it from the list.
- **Expandable Episode Descriptions**: Podcast episode descriptions now have a "Show more / Show less" toggle.
- **Show More for Genre Catalogs**: Genre sections show 10 items by default with a "Show all" card for the rest.

### Fixed & Improved
- **Podcast Progress Not Lost on Stop**: Stopping a podcast no longer clears the saved position — your place is always preserved.
- **Mini Player Tap No Longer Restarts**: Tapping Continue Listening for an already-loaded episode just resumes playback instead of force-replacing and re-seeking.
- **Podcast Duration Accuracy**: Episode duration now comes from the actual audio file instead of the RSS feed (which often omits it), fixing "0 secs left" display.
- **Riverpod Dispose Safety**: Fixed crash when saving podcast progress during widget disposal by caching notifier references.
- **iTunes RSS Namespace Parsing**: Fixed broken `<itunes:image>` parsing across all RSS methods by switching to manual namespace filtering.
- **Per-Episode Artwork**: Episode-specific artwork from RSS feeds now displays correctly in mini player and continue listening.
- **Episode Artwork in Continue Listening**: Saved continue-listening entries now persist and display episode artwork.
- **Seek Icons Match Behavior**: Rewind/forward icons show 10s and seek by 10s (was 15s).
- **Skip Buttons Repurposed for Podcasts**: Previous/next track buttons now seek ±60s instead of switching episodes.
- **Mini Player Stop Button Taps**: Stop button no longer propagates tap to the parent InkWell (no longer opens now-playing on stop).
- **Genre Pagination Fixed**: Removed offset-based iTunes pagination (which cycled same results); now fetches 100 podcasts per genre in one call.
- **Bottom Padding for Mini Player**: Listing screen bottom spacing increased so last row isn't hidden behind the mini player.

## [1.0.5] - June 2026

> ⚠️ **Audiobooks are in Beta** — Some features may be rough around the edges. Feedback is welcome!

### Added
- **Bookmarks for Audiobooks**: You can now bookmark your favorite moments in any audiobook. Tap the bookmark icon in the Now Playing screen to save your exact spot — chapter and time position. Each bookmark can be named, and you can tap any bookmark to jump right back to that moment.
- **Bookmarks Tab**: The chapters and bookmarks sections are now organized into tabs, making it easier to switch between browsing chapters and managing your saved bookmarks.
- **Notification Bookmark Button**: When listening to an audiobook, a bookmark button appears in the system notification. You can save a bookmark without even opening the app.
- **Bookmarks Backed Up**: Bookmarks are automatically saved to your audiobook's backup folder, so they're included in your backups and restored when you re-scan your library.
- **Android Auto Support**: Audiobooks now work with Android Auto for a safer in-car listening experience.
- **Download Progress in Notification**: The download notification now shows exactly how many MB have been downloaded out of the total size, not just the percentage.

### Fixed & Improved
- **EPUB Reader Improvements**: Better support for EPUB3 files — chapters, bold and italic text, and special characters now display correctly.
- **Library Scan Fix**: EPUB files now show up properly in your local library, and loose files in your audiobook folder are automatically organized into subfolders.
- **AudiobookBay Torrents Fixed**: Downloading from AudiobookBay search results to TorBox now works correctly.
- **Download Button Reliable**: The download button in the book detail screen now handles AudiobookBay links properly, so you can save books to listen offline.
- **Bookmark Count Stays Updated**: The bookmark badge reliably updates when bookmarks are added or cleared.

## [1.0.4] - June 2026

> ⚠️ **Audiobooks are in Beta** — Some features may be rough around the edges. Feedback is welcome!

### Added
- **Audiobooks (Beta)**: Audiobooks are now available! Books automatically detect and display their internal chapters — each chapter listed with its title, start time, and duration.
- **Chapter-Aware Progress**: Progress is now tracked per chapter, so you always resume exactly where you left off — even mid-chapter.
- **Live Chapter Updates**: The mini player and system notification automatically update to show the current chapter name as you listen, in real time.
- **MP3 Audiobook Chapters**: Added support for MP3 audiobooks that embed chapter information — chapters are now detected and listed just like M4B files.
- **Read While You Listen**: A new 📖 book icon appears in the Now Playing screen whenever an EPUB file is found alongside your audiobook. Tap it to open the full book text and read while the audio plays in the background.
- **Built-in Book Reader**: The reader supports chapter navigation, adjustable font size (larger or smaller), and a table of contents. Tap anywhere on the page to hide the controls for a distraction-free reading experience.
- **Reading Position Saved**: The book reader remembers exactly where you were — which chapter and how far down the page — and returns you there every time you reopen the book. Your font size preference is also saved per book.
- **Progress Saved to Backup Folder**: Audiobook listening progress is now saved as a file inside the book's own folder, so it's included in your backups automatically.
- **Completed Chapter Tracking**: Chapters you've finished are now correctly marked as completed. When the audio naturally moves to the next chapter, the previous one is saved as done — so your progress overview always reflects reality.

### Fixed & Improved
- **Chapter Highlighting**: The currently playing chapter is now highlighted in both the Now Playing and book detail screens as the audio progresses.
- **Audiobook in Mixed Folders**: Audiobooks stored alongside other files (covers, samples, etc.) now correctly show only the real audio chapters instead of listing every file.
- **Notification & Mini Player Accuracy**: Fixed chapter title not updating in the notification bar and mini player when crossing chapter boundaries.
- **Smarter Chapter Completion**: Fixed a bug where chapters near the end of a book were never marked as finished. A chapter is now correctly marked complete when you finish it or skip forward to the next one.

## [1.0.3] - June 2026

### Added
- **Maximum Screen Smoothness**: Added support for 90Hz, 120Hz, and 144Hz displays, making animations and scrolling feel incredibly fluid on devices with high refresh rate screens.
- **Dynamic Artwork Colors**: The app now automatically styles itself using colors extracted from the currently playing song's artwork, blending themes beautifully.
- **Google Material 3 Theme Style**: Added a clean, dynamic card-based design style as a fresh look alongside the classic Apple Music layout.
- **Interactive Mini Player Gestures**: Swipe left or right on the bottom mini player to skip songs, complete with springy dragging physics.
- **Import Playlists & Links**: Share Spotify or YouTube links from other apps directly to Isai to import whole playlists or stream tracks instantly.
- **Liquid Glass Settings**: Customize the frosted glass background transparency with a new slider in the appearance settings.

### Fixed & Improved
- **Cleaner Screen Transitions**: Closing the full player now fades out the background smoothly while the song artwork flies directly into its place on the mini-player, removing the distracting sliding blur effect.
- **Buttons & Menus Visibility**: Fixed unreadable text on the album screen Play/Shuffle buttons, and polished the 3-dot options menu layout for better contrast in light mode.
- **Theme Color Fixes**: Fixed issues where black icons or text would show on dark backgrounds when switching between light and dark modes.
- **Queue Playback Fixes**: Fixed a bug where the music queue would sometimes repeat the same song instead of playing the next.
- **Stream Reliability**: Improved backend retrying when streaming tracks so songs load more reliably on slower networks.
- **UI Spacing Polish**: Cleaned up alignments, margins, and layouts on settings, album, and discovery screens for a cleaner appearance.

## [1.0.2] - June 2026

### Added
- **Link Sharing**: You can now share Spotify and YouTube links from other apps directly into Isai. The song starts playing automatically with high-quality source resolution.
- **Playlist Importing**: Sharing a Spotify or YouTube playlist link automatically detects and imports the full playlist into your local library.
- **Haptic Feedback**: Added subtle vibration feedback when tapping songs, pressing buttons, or using filter chips throughout the app.
- **Lyrics Fine-Tuning**: Synced lyrics can now be adjusted forward or backward by half a second to match the audio perfectly.
- **Linux AppImage Support**: Added portable Linux builds (.AppImage) alongside .tar.gz in GitHub releases.

### Fixed & Improved
- **Cleaner Layouts**: Redesigned spacing and alignment on the Discovery, Album, and Settings screens for a more polished look.
- **Download Warnings**: The Now Playing screen now shows clear warnings when no download folder is set, with a direct link to settings.
- **Smarter Recommendations**: Fixed the "For You" page from unnecessarily re-fetching recommendations on every visit by loading your listening history directly from the database.
## [1.0.0] - June 2026

### Added
- First public release of Isai music player.
- Premium Apple Music-inspired glassmorphism user interface.
- Integration with TorBox to stream audio files from torrents directly.
- Support for multiple high-quality music streaming plugins: JioSaavn, MassTamilan.
- Advanced features including real-time synced lyrics, local downloads, and queue management.
- Dynamic plugin ecosystem to load custom JavaScript-based scrapers.
- Responsive design supporting Android mobile, tablets.
