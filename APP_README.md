# ReShade Metal Installer (macOS 26+)

A native SwiftUI front end for the repository's experimental ReShade/D3DMetal compatibility patch. It installs into a 64-bit Windows game's directory inside a Wine, Whisky, or CrossOver bottle.

## Build and run

Requirements: macOS 26 or later and Xcode with the macOS 26 SDK.

1. Open `ReShadeMetalInstaller.xcodeproj` in Xcode.
2. Select the `ReShadeMetalInstaller` scheme and a Mac destination.
3. Build and run, or use the command below from this directory:

   ```sh
   xcodebuild -project ReShadeMetalInstaller.xcodeproj \
     -scheme ReShadeMetalInstaller -configuration Release \
     -derivedDataPath build/DerivedData build
   ```

   The app is written to `build/DerivedData/Build/Products/Release/ReShadeMetalInstaller.app`.

## Install a game

1. Install and launch the Windows game once from its Wine-based wrapper, then close it.
2. In ReShade Metal Installer, choose the game's actual 64-bit `.exe` in the bottle/prefix.
3. Choose whether to download the official ReShade shader collection.
4. Choose a ReShade version in **Choose the ReShade version**. The selector lists only builds with verified setup/runtime hashes and a matching D3DMetal patch profile. The currently verified x64 versions are **4.1.1, 4.2.1, 4.3.0, 4.4.2, 4.5.4, 4.6.1, 4.7.0, 4.8.2, 4.9.1, 5.0.0, 5.0.2, 5.1.0, 5.2.2, 5.3.0, 5.4.2, 5.5.2, 5.6.0, 5.7.0, 5.8.0, 5.9.2, 6.7.2, and 6.8.0**. Select **Install ReShade** to download the selected build, verify its hashes, apply the matching local patch, and install the patched `dxgi.dll` and configuration files beside the executable.
5. If a game already has a `dxgi.dll`, the installer retains it as `dxgi.original.dll` and configures ReShade to proxy it. It refuses a pre-existing `dxgi.original.dll` in that case to avoid overwriting an existing proxy chain.
6. In the wrapper's Wine settings, enable a **native** `dxgi` override (use Builtin as fallback if the wrapper offers that choice) and keep D3DMetal enabled. Launch the game and press **Home** to open ReShade's overlay.

The installer creates a hidden `.ReShadeMetalBackup-*` folder and a `.reshade-metal-install.json` manifest beside the game executable. Select that same game again and choose **Restore backup** to remove the installed files and restore backed-up files. Keep the backup folder until the game has launched successfully.

## Configure shaders per game

Open **Shaders** and use **Add game** to register each game's 64-bit `.exe`. The page keeps a persistent list of games; expand any game card to manage only that game's shaders. Each card lists techniques discovered in that game's `reshade-shaders/Shaders` `.fx` files, shows which are enabled, and lets you search, toggle individual effects, or use **Enable all** / **Disable all**. Changes are saved immediately to that game's `ReShadePreset.ini`, using ReShade's `TechniqueName@ShaderFile.fx` identifiers. Each game directory has its own preset, so changing one game's effect selection does not change another game's settings. Games without ReShade installed remain in the list and show an installation prompt; their shader controls become available after installing ReShade with the shader collection. **Remove from list** only unregisters the game and does not delete or modify its files. The game list is stored in the app's Application Support folder.

## Scope and safety

- The patch accepts only the 22 x64 builds listed above. Each version has its own checked setup/runtime hashes, patch locations, byte signatures, and expected patched output hash; unsupported versions are rejected. The installer validates the PE headers and writes its hook into a dedicated executable `.rguard` section, checking that the hook site falls inside the declared `.text` section.
- ReShade 4.0.2 is excluded because its archived setup did not provide an x64 runtime. ReShade 5.1.1 is excluded because the required archived artifacts were unavailable. Versions 6.0.0 through 6.7.1 are not enabled because the compatibility hook layout has not been verified for those builds.
- The supported injection path is 64-bit DXGI. Other graphics APIs and 32-bit games are not supported by this build.
- The shader archive is downloaded from the ReShade shader repository's `slim` branch. Shader downloads are optional.
- This is an experimental community compatibility patch, not an official ReShade release. Injection may break a game or conflict with anti-cheat. Use with games and prefixes you control, and keep the automatic backup until the result is confirmed.

## Verified artifacts

### ReShade 6.8.0 x64

- ReShade setup SHA-256: `207aea16205fbf952bc8fe1879966672454cf04002e7ad34237c7990a5b3c0b4`
- Official `ReShade64.dll` SHA-256: `b2945c29e7095491a901746b400e58db9b1592ab092bacf2a888ce37f02d08da`
- Patched `dxgi.dll` SHA-256: `8452bd0220d36b175babfce52d2395ef21dc47d59f116d718c287292ace2fc2a`

### ReShade 6.7.2 x64

- ReShade setup SHA-256: `92ad42fb05187fc03e40c4b86eb87410b0068f1ee6bef19d2db52294b529cde0`
- Official `ReShade64.dll` SHA-256: `789a47742f9a9bdf14202a1d00ac98d2fef8f1240adb5e1f9ffa651b0df728a7`
- Patched `dxgi.dll` SHA-256: `1cffb3fc0b89338176b4c5c55eb20fd66ce612808d7d6c7ac30ad090c395c2b6`

## Subnautica 6.8.0 compatibility

The 6.8.0 profile also forces ReShade’s internal Device1 queries to use legacy blend-state creation, restoring overlay text on D3DMetal. New installations disable Generic Depth and Effect Runtime Sync; with these add-ons enabled Subnautica stalls during startup. Depth-dependent effects are unavailable while Generic Depth is disabled. Verified at the main menu with a readable, interactive ReShade overlay.
