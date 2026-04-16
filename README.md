# SonicBar

A lightweight, native macOS dynamic notch music player for [Subsonic](http://www.subsonic.org/)/[Navidrome](https://www.navidrome.org/) servers.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Screenshot
<img width="613" height="414" alt="image" src="https://github.com/user-attachments/assets/8dccbb3d-1c41-4219-82d1-8032139e7150" />

## Features

- **Menu Bar Player** — One hover away
- **Native macOS Design** — Glassmorphism, smooth animations
- **Gapless Playback** — Preloaded next tracks
- **Media Key Support** — System-wide controls
- **Library Browser** — Browse albums and art
- **Now Playing Integration** — System Control Center support

## Requirements

- macOS 13.0 (Ventura) or later
- A Subsonic-compatible server (Navidrome, Airsonic, Subsonic, etc.)

```bash
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
├── Assets/                 # Static assets (AppIcon)
├── Sources/
│   ├── Core/               # App lifecycle and main player logic
│   ├── UI/                 # SwiftUI views and UI state
│   ├── Services/           # API clients (Subsonic, Jellyfin, Local)
│   └── Utils/              # Helpers (Keychain, Notch detection)
├── build.sh                # Main build script
└── README.md
```

## License

MIT License — see [LICENSE](LICENSE) for details.
