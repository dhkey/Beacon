# Beacon

Beacon is a fast, native application launcher for macOS. Open it from anywhere with a global keyboard shortcut, search installed apps and common destinations, then press Return to launch the selected result.

## Features

- Native SwiftUI and AppKit interface
- Global launcher shortcut (`⌥ Space` by default)
- Search across system and user Applications folders
- Case-insensitive, diacritic-insensitive fuzzy matching
- Quick access to System Settings, Downloads, and Applications
- Web search fallback in the default browser
- Keyboard navigation with the arrow keys and Return
- Configurable shortcut and manual application reindexing
- Menu-bar operation with no Dock icon

## Requirements

- macOS 26.0 or later
- Xcode 26 or later

## Build and run

1. Clone the repository:

   ```sh
   git clone https://github.com/dhkey/Beacon.git
   cd Beacon
   ```

2. Open `Beacon.xcodeproj` in Xcode.
3. Select the **Beacon** scheme and run the project.

You can also build from the command line:

```sh
xcodebuild -project Beacon.xcodeproj -scheme Beacon -configuration Debug build
```

## Releases

Every push and pull request to `main` is built and tested by GitHub Actions. Pushing a semantic version tag automatically creates a GitHub Release containing universal DMG, PKG, and ZIP packages with SHA-256 checksums:

```sh
git tag v1.0.1
git push origin v1.0.1
```

## Install a release

1. Download the DMG from the [latest GitHub Release](https://github.com/dhkey/Beacon/releases/latest).
2. Open the DMG and drag **Beacon** into the **Applications** folder.
3. In Applications, Control-click **Beacon**, choose **Open**, and confirm the macOS security prompt.

The PKG provides a guided installer, while the ZIP contains the standalone application. The packages are ad-hoc signed because the project does not use a paid Apple Developer account, so the first-launch security confirmation is unavoidable. Developer ID signing and notarization can be added later without changing the release process.

## Usage

1. Press `⌥ Space` to show or hide Beacon.
2. Type an application or command name.
3. Use `↑` and `↓` to move through results.
4. Press `Return` to open the selected result, or `Esc` to dismiss Beacon.

Open **Beacon Settings** from the launcher or menu-bar item to record a different global shortcut or rebuild the application index.

## Tests

Run the unit and UI test targets with:

```sh
xcodebuild test -project Beacon.xcodeproj -scheme Beacon -destination 'platform=macOS'
```

## Project structure

```text
Beacon/
├── BeaconApp.swift                 # App lifecycle and menu-bar entry
├── ContentView.swift               # Launcher interface
├── KeyboardShortcut.swift          # Shortcut representation and registration
├── LauncherModel.swift             # Indexing, matching, and launch behavior
├── LauncherPanelController.swift   # Floating launcher panel
└── SettingsView.swift              # Shortcut and indexing settings
```

Beacon indexes application metadata locally. A web-search result opens Google in your default browser only when you choose it.
