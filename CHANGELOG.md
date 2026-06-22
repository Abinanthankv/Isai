# Changelog

## [1.0.4] - June 2026

> ⚠️ **Audiobooks are in Beta** — Some features may be rough around the edges. Feedback is welcome!

### Added
- **Audiobooks (Beta)**: Audiobooks are now available! Books automatically detect and display their internal chapters — each chapter listed with its title, start time, and duration.
- **Chapter-Aware Progress**: Progress is now tracked per chapter, so you always resume exactly where you left off — even mid-chapter.
- **Live Chapter Updates**: The mini player and system notification automatically update to show the current chapter name as you listen, in real time.
- **MP3 Audiobook Chapters**: Added support for MP3 audiobooks that embed chapter information — chapters are now detected and listed just like M4B files.

### Fixed & Improved
- **Chapter Highlighting**: The currently playing chapter is now highlighted in both the Now Playing and book detail screens as the audio progresses.
- **Audiobook in Mixed Folders**: Audiobooks stored alongside other files (covers, samples, etc.) now correctly show only the real audio chapters instead of listing every file.
- **Notification & Mini Player Accuracy**: Fixed chapter title not updating in the notification bar and mini player when crossing chapter boundaries.

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

## [1.0.0] - June 2026

### Added
- First public release of Isai music player.
- Premium Apple Music-inspired glassmorphism user interface.
- Integration with TorBox to stream audio files from torrents directly.
- Support for multiple high-quality music streaming plugins: JioSaavn, MassTamilan.
- Advanced features including real-time synced lyrics, local downloads, and queue management.
- Dynamic plugin ecosystem to load custom JavaScript-based scrapers.
- Responsive design supporting Android mobile, tablets.
