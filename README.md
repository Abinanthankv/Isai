<p align="center">
  <img src="assets/isai_app_icon.png" width="120" alt="Isai App Icon"/>
</p>

<h1 align="center">Isai</h1>
<p align="center">A premium music, podcast & audiobook player powered by TorBox — stream FLACs, podcasts, and audiobooks from multiple sources.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&style=for-the-badge&logoColor=white" />
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&style=for-the-badge&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&style=for-the-badge&logoColor=white" />
</p>

---

## 🌟 Features

### 🎵 Music
- **Multi-source Streaming** — JioSaavn, MassTamilan, Internet Archive, YouTube.
- **TorBox Library Integration** — Stream your TorBox files directly without downloading.
- **Smart Source Selection** — Auto-picks the best quality match per track.
- **Import Playlists** — Import YouTube, Spotify, and Tidal playlists via share intent.
- **Album & Artist Browsing** — Powered by the iTunes Search API.
- **Queue Management** — Full queue support with reordering, shuffle, and repeat.
- **Synced Lyrics** — Real-time synced lyrics display when playing tracks.
- **Last.fm Scrobbling** — Scrobble your plays to your Last.fm profile automatically.

### 🎙️ Podcasts
- **Podcast Discovery** — Browse trending, new & noteworthy, and genre-categorized podcasts via iTunes.
- **Episode Browsing** — View all episodes with descriptions, durations, and release dates per podcast.
- **Follow Your Favorites** — Follow podcasts to keep them in a dedicated section.
- **Progress Persistence** — Episode progress is saved automatically. Resume any in-progress episode from where you left off.
- **Multi-Episode Tracking** — All in-progress episodes (across different podcasts) appear in the Continue Listening section.
- **Playback Speed** — Adjustable speed (0.5x–2.0x) with sleep timer.

### 📚 Audiobooks (Beta)
- **Chapter-Aware Playback** — Automatically detects chapters from M4B and MP3 files.
- **EPUB Reader** — Read alongside audio with synced chapter navigation.
- **Bookmarks** — Save and name bookmarks at any position.
- **Progress Tracking** — Per-chapter progress saved to the book's folder for backup.
- **TorBox Integration** — Stream audiobooks directly from TorBox.
- **Android Auto Support** — Audiobooks work with Android Auto.
- **Hardcover Sync** — Sync progress and wishlist with Hardcover.

### 🎨 UI & Experience
- **Apple Music-inspired Design** — Glassmorphism design system with dark/light mode.
- **Material 3 Theme** — Dynamic color extraction from artwork, with custom accent colors.
- **High Refresh Rate** — Optimized for 90Hz, 120Hz, and 144Hz displays.
- **Mini Player Gestures** — Swipe to skip tracks with spring physics.
- **In-App Updates** — Detects new releases and updates directly within the app.
- **Linux & Windows Support** — Runs on desktop platforms with feature parity.

### 🔌 Extensibility
- **Dynamic Plugin System** — JavaScript-based scraper plugins for new music sources.
- **Eclipse Addon Support** — Integrates with Eclipse addons for expanded catalogs.

---

## 📱 Requirements

| Platform | Minimum |
|---|---|
| Android | 7.0+ (Nougat) |
| Linux | Any modern distro |
| Windows | Windows 10+ |
| **SDK** | Flutter 3.x |

A [TorBox](https://torbox.app) account is optional — can be skipped to use external streaming sources only.

---

## 🚀 Getting Started

```bash
# Clone the repository
git clone https://github.com/Abinanthankv/Isai.git
cd Isai

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run
```

### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# Linux (AppImage)
flutter build linux
# Then package with: linux/packaging/make_appimage.sh

# Windows (requires Windows machine with Visual Studio)
flutter build windows
```

---

## ⚙️ Configuration

1. **TorBox Integration**: On first launch, enter your **TorBox API key** (found at [torbox.app](https://torbox.app) → Account → API Keys). Can be skipped to run solely on streaming sources.
2. **Music Sources**: Toggle providers (YouTube, Tidal, JioSaavn, MassTamilan, Archive.org) in **Settings → Music Sources**.
3. **Last.fm**: Connect your Last.fm account in **Settings → Scrobbling**.
4. **Hardcover**: Connect your Hardcover account for audiobook sync in **Settings → Hardcover**.

---

## 🛠️ Tech Stack

| Layer | Technology | Description |
|---|---|---|
| **Framework** | Flutter + Dart | Cross-platform UI development |
| **State Management** | Riverpod | Clean architecture with injected services |
| **Audio Engine** | `just_audio` / `media_kit` (Linux) + `audio_service` | High-fidelity playback with OS media controls |
| **Database** | Drift (SQLite) | Type-safe local storage |
| **Network Client** | Dio | HTTP client with interceptors |
| **Metadata** | iTunes Search API | High-resolution album/artist metadata |
| **Podcasts** | iTunes Podcast API + RSS/XML parsing | Episode discovery and feed fetching |
| **Audiobooks** | M4B/MP3 chapter parsing + EPUB3 support | Chapter-aware playback and reading |
| **Plugin Host** | QuickJS via `flutter_js` | Sandboxed scraper runtime |
| **Scraping** | `youtube_explode_dart`, custom JS plugins | Source-specific stream extraction |
| **DI** | Injectable + GetIt | Dependency injection and service location |

---

## ⚖️ Legal & Disclaimer

Isai functions solely as a client-side interface for browsing metadata and playing media provided by user-installed extensions and/or user-provided sources. It is intended for content the user owns or is otherwise authorized to access.

Isai is not affiliated with any third-party extensions, catalogs, sources, or content providers. It does not host, store, or distribute any media content.

For comprehensive legal information, including our full disclaimer, third-party extension policy, and DMCA/Copyright information, please see the [LICENSE](LICENSE) file.

