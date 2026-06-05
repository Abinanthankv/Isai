# Changelog

## [1.0.2] - June 2026

### Added
- External plain-text link sharing: Intercept Spotify and YouTube song links shared from other apps and play them instantly using high-quality lazy source resolution.
- Integrated `ShareHandlerService` and updated `AndroidManifest.xml` to handle incoming `SEND` sharing intents.
- Added `receive_sharing_intent` package to dependencies.
- Native tactile haptic feedback on song selections, long presses, buttons, and filter chips across presentation screens.
- Interactive synced lyrics offset controls (+/- 0.5s) to delay or speed up lyrics sync.

### Fixed & Improved

- Redesigned and cleaned up UI layout/spacing on Discovery, Album, and Settings screens for cleaner layouts and improved responsiveness.
- Surfaced download directory configuration warnings with direct settings redirect links on the Now Playing player screen.
- Prevented automatic recommendations rebuilding/re-fetching on the "For You" page by loading history profile via direct database queries.

## [1.0.1] - June 2026

### Fixed
- Fixed JioSaavn playlist queue playback bug where it repeated the first song.
- Fixed missing artist names in the playback source selection sheets.

## [1.0.0] - June 2026

### Added
- First public release of Isai music player.
- Premium Apple Music-inspired glassmorphism user interface.
- Integration with TorBox to stream audio files from torrents directly.
- Support for multiple high-quality music streaming plugins: JioSaavn, MassTamilan.
- Advanced features including real-time synced lyrics, local downloads, and queue management.
- Dynamic plugin ecosystem to load custom JavaScript-based scrapers.
- Responsive design supporting Android mobile, tablets.
