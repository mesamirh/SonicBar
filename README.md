# SonicBar

A lightweight, native macOS menu bar music player for [Subsonic](http://www.subsonic.org/)/[Navidrome](https://www.navidrome.org/) servers.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Screenshot
<img width="613" height="414" alt="image" src="https://github.com/user-attachments/assets/8dccbb3d-1c41-4219-82d1-8032139e7150" />

## Features

- 🎵 **Menu Bar Player** — Drops down from the top of your screen, always one hover away
- 🎨 **Native macOS Design** — Glassmorphism, smooth animations, dark mode
- advancement **Gapless Playback** — AVQueuePlayer with next-track preloading
- ⌨️ **Media Key Support** — Play/pause/skip from your keyboard
- 📀 **Library Browser** — Browse albums with cover art thumbnails
- 🔀 **Radio Mode** — Automatic shuffle with continuous playback
- 🖼️ **Now Playing Integration** — Album art and track info in Control Center

## Requirements

- macOS 13.0 (Ventura) or later
- A Subsonic-compatible server (Navidrome, Airsonic, Subsonic, etc.)

## Build

No Xcode required — compiles with `swiftc` directly:

```bash
chmod +x build.sh
./build.sh
```

This creates `SonicBar.app` in the project directory.

## Usage

1. Open `SonicBar.app`
2. Hover over the top-center of your screen to reveal the player
3. Enter your server URL, username, and password
4. Music starts playing automatically

**Controls:**
- **Hover** the top edge of screen to expand the player
- **Move away** to collapse
- **Long press** on the player to access Settings and Quit

## Project Structure

```
SonicBar/
├── SonicBarApp.swift      # App entry point & window config
├── ContentView.swift      # Main UI (player, settings, library)
├── AudioPlayer.swift      # AVQueuePlayer wrapper & media controls
├── SubsonicClient.swift   # Subsonic/Navidrome REST API client
├── build.sh               # Build script (no Xcode needed)
├── AppIcon.png            # App icon source (1024x1024)
└── .gitignore
```

## License

MIT License — see [LICENSE](LICENSE) for details.
