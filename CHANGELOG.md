# Changelog

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
