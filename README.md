<p align="center">
  <img src="assets/isai_app_icon.png" width="120" alt="Isai App Icon"/>
</p>

<h1 align="center">Isai</h1>
<p align="center">A high-fidelity music, podcast & audiobook player powered by TorBox — stream FLACs, podcasts, and audiobooks.</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&style=for-the-badge" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&style=for-the-badge&logoColor=white" />
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&style=for-the-badge&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&style=for-the-badge&logoColor=white" />
</p>

---

## 🌟 Key Features

### 🎵 High-Fidelity Music & Audio Inspection
- **Multi-source Streaming** — JioSaavn, MassTamilan, Internet Archive, YouTube, and Deezer.
- **TorBox Debrid Integration** — Stream your audio files directly from TorBox without prior downloading.
- **Bit-Perfect USB Output** — Direct USB DAC mode bypassing the Android AudioFlinger system resampler for 1:1 bit-perfect playback (Android 14+).
- **3-Segmented Audio Quality & Metadata Sheet**:
  - ℹ️ **Track Metadata**: Full song metadata (Track/Disc numbers, Duration, Audio Quality Badge, Cover resolution, Release Date, Genre, Label, Copyright, Composers, Comment URL, ISRC, Deezer ID) with **Tap & Hold to Copy** on every field.
  - 🔀 **Audio Signal Path**: Poweramp-styled 5-stage node pipeline (*Track Source → Audio Decoder → Resampler & DSP → Android Output Engine → Active Hardware Output*) featuring real-time Bluetooth A2DP codec detection (**LDAC**, **AptX HD**, **AAC**, **SBC**) and USB DAC sample rates.
  - 📊 **Audio Quality Analysis**: Real PCM audio metrics (**ITU-R BS.1770-4 LUFS**, **Peak/RMS dB**, **True Peak dBTP**, **Nyquist frequency**, **Spectral Cutoff**, **Dynamic Range**, **Clipping detection**, **Per-channel statistics**).
- **Smart Source Selection** — Auto-picks the best quality match per track.
- **Import Playlists** — Import YouTube, Spotify, and Tidal playlists via share intent.
- **Synced Lyrics** — Real-time synced lyrics display when playing tracks.
- **Last.fm Scrobbling** — Scrobble plays to your Last.fm profile automatically.

### 🎙️ Podcasts
- **Podcast Discovery** — Browse trending, new & noteworthy, and genre-categorized podcasts via iTunes.
- **Episode Browsing & Resuming** — Descriptions, durations, release dates, and saved playback progress per episode.
- **Multi-Episode Tracking** — In-progress episodes across different podcasts appear in the *Continue Listening* section.
- **Playback Controls** — Variable speed (0.5x–2.0x) and sleep timer.

### 📚 Audiobooks & EPUB Reader
- **Chapter-Aware Playback** — Auto-detects chapters from M4B and MP3 files.
- **Integrated EPUB Reader** — Read alongside audio with synced chapter navigation.
- **Bookmarks & Progress** — Save named bookmarks and per-chapter progress.
- **Hardcover Integration** — Sync progress and reading wishlist with Hardcover.app.
- **Android Auto Support** — Browse and listen to audiobooks safely in your car.

### 🎨 UI & Performance
- **Dual Design Engine** — Toggle between **Apple Music Acrylic** glassmorphism and **Google Material 3 (Expressive)** dynamic color extraction.
- **120Hz Smooth Scrolling** — Optimized layout with `RepaintBoundary` card isolation and zero GPU blur overdraw.
- **Mini Player Gestures** — Interactive swipe physics to skip tracks.
- **Cross-Platform** — Native support for Android, Linux, and Windows desktop.

### 🔌 Extensibility & Cloud Sync
- **Dynamic Scraper Plugins** — Sandboxed JavaScript runtime for custom music sources.
- **Eclipse Cloud Sync & Addon Integration** — Sync playlists, history, and integration with Eclipse addons.

---

## 🙏 Credits & Inspiration

Isai draws design, technical, and architectural inspiration from several fantastic open-source and audio projects:

- **[SpotiFLAC / Spotic](https://github.com/SpotiFLAC)** — Inspiration for comprehensive track metadata breakdown, Deezer/ISRC enrichment, and bit depth/sample rate quality badge displays.
- **[Eclipse](https://github.com)** — Inspiration for cloud account sync, cross-device history/playlist synchronization, and addon ecosystem integration.
- **[Poweramp](https://powerampapp.com)** — Inspiration for the high-res 5-stage audio signal path flow visualization and native Android output hardware codec detection.
- **[Apple Music](https://www.apple.com/apple-music/) & [Google Material 3](https://m3.material.io/)** — Design inspiration for glassmorphic acrylic visuals and dynamic palette color extraction.

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

# Windows
flutter build windows
```

---

## ⚙️ Configuration

1. **TorBox Integration**: Enter your **TorBox API key** in **Settings → Account** (found at [torbox.app](https://torbox.app) → Account → API Keys).
2. **Music Sources**: Toggle providers in **Settings → Music Sources**.
3. **Bit-Perfect USB Output**: Enable in **Settings → Player Customization** for direct USB DAC audio streaming.
4. **Last.fm & Hardcover**: Connect your accounts in **Settings** for scrobbling and reading list sync.

---

## 🛠️ Tech Stack

| Layer | Technology | Description |
|---|---|---|
| **Framework** | Flutter + Dart | Cross-platform UI development |
| **State Management** | Riverpod | Clean architecture with reactive providers |
| **Audio Engine** | `just_audio` / `media_kit` + `audio_service` | High-fidelity playback with OS media controls |
| **Audio Analysis** | Native PCM Analyzer (FFmpeg/WAV) | LUFS, True Peak, Nyquist, and spectral cutoff calculation |
| **Hardware Bridge** | Kotlin MethodChannel (`AudioDevicePlugin`) | Android A2DP Bluetooth codec & USB DAC output detection |
| **Database** | Drift (SQLite) | Type-safe local storage |
| **Network Client** | Dio | HTTP client with interceptors |
| **Metadata** | iTunes Search API & Deezer API | High-resolution metadata enrichment |
| **Plugin Host** | QuickJS via `flutter_js` | Sandboxed scraper runtime |
| **DI** | Injectable + GetIt | Dependency injection and service location |

---

## ⚖️ Legal & Disclaimer

Isai functions solely as a client-side interface for browsing metadata and playing media provided by user-installed extensions and/or user-provided sources. It is intended for content the user owns or is otherwise authorized to access.

Isai is not affiliated with any third-party extensions, catalogs, sources, or content providers. It does not host, store, or distribute any media content.

For comprehensive legal information, please see the [LICENSE](LICENSE) file.
