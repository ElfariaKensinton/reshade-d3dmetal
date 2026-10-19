# ReShade Metal Installer

ReShade Metal Installer is a native macOS app for installing a verified, D3DMetal-compatible ReShade build into a 64-bit Windows game running in a Wine-based wrapper such as CrossOver or Whisky.

The installer downloads the selected official ReShade setup, verifies its SHA-256, applies the matching version-specific DXGI compatibility patch, and installs the files beside the game's executable. It can also fetch the ReShade shader collection. Existing game files are backed up so the install can be restored from the app.

> This is an experimental community project, not an official ReShade release. Compatibility is limited to the versions shown in the app. Keep a backup and avoid using DLL injection with games whose anti-cheat rules prohibit it.

## Features

- Installs verified ReShade x64 builds with a matching D3DMetal patch profile.
- Supports DXGI injection for 64-bit Windows games in Wine, Whisky, and CrossOver bottles.
- Verifies downloaded setup and runtime files before patching.
- Backs up replaced game files and provides a restore action.
- Optionally downloads shaders and manages enabled techniques per game.

## Requirements

- macOS 26 or later
- Xcode with the macOS 26 SDK to build from source
- A 64-bit Windows game installed in a Wine-based wrapper
- D3DMetal enabled in that wrapper

## Build

Open `ReShadeMetalInstaller.xcodeproj` in Xcode, choose the `ReShadeMetalInstaller` scheme, and build for your Mac. Or run:

```sh
xcodebuild \
  -project ReShadeMetalInstaller.xcodeproj \
  -scheme ReShadeMetalInstaller \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The app bundle is created at `build/DerivedData/Build/Products/Release/ReShadeMetalInstaller.app`.

## Download a build

Open the repository's **Actions** tab and run **Build ReShade Metal Installer**. Every run uploads a downloadable app bundle artifact. To publish a GitHub Release as well, enable **Publish a GitHub Release** before starting the run. The workflow generates a date-and-build-number tag and a matching release title automatically.

The release contains a ZIP of the app bundle and a SHA-256 checksum file. The app is currently unsigned; macOS may require you to approve or remove quarantine from a build downloaded from GitHub.

## Install into a game

1. Launch the game once from CrossOver, Whisky, or another Wine wrapper, then close it.
2. Open ReShade Metal Installer and choose the game's actual 64-bit `.exe` inside the bottle.
3. Choose whether to download the ReShade shader collection and select one of the compatible ReShade versions shown in the app.
4. Select **Install ReShade**. The installer verifies the official downloads, applies the matching patch, and saves a backup beside the game executable.
5. In the wrapper's Wine settings, set the `dxgi` library override to **Native** (with **Builtin** fallback if available), keep D3DMetal enabled, and launch the game. Press **Home** to open the ReShade overlay.

Choose the same game in the installer and select **Restore backup** to undo the installation. Keep the backup until you have confirmed the game works.

For shader controls, open **Shaders**, add a game's `.exe`, then expand its card to search, enable, or disable effects. Each game has its own preset.

## Compatibility and details

This project is experimental and supports only the 64-bit DXGI path and the ReShade versions that have verified patch profiles in the app. Unsupported builds are rejected. Some versions have additional compatibility adjustments; the app configures those profiles automatically. See [APP_README.md](APP_README.md) for detailed installation behavior and verified build information.

`patch.py` is a standalone reproduction of the verified ReShade 6.8.0 x64 patch. It accepts the matching original DLL only and refuses to overwrite its output. Most users should use the installer instead.

## License

This repository contains a community installer and compatibility patch for ReShade. ReShade remains subject to its own license and notices; see [the upstream ReShade project](https://github.com/crosire/reshade) for its source and licensing terms.
