# Subnautica ReShade / D3DMetal compatibility patch

> For the native installer and supported versions, see [APP_README.md](APP_README.md).

Target: official ReShade 6.8.0 x64, SHA-256 b2945c29e7095491a901746b400e58db9b1592ab092bacf2a888ce37f02d08da.

The patch changes ReShade's internal ID3D11Device3 and ID3D11Device1 query identifiers, selecting its existing legacy resource-view and blend-state creation paths. This fixes overlay glyphs rendering as solid blocks on D3DMetal. It also guards the DXGI ResizeBuffers entry point: requests whose dimensions, buffer count, format and flags already match return S_OK without destroying the runtime. Changed requests retain the original implementation. This is a version-specific experimental binary patch, not an upstream ReShade release.

`patch.py ORIGINAL_DLL OUTPUT_DLL` reproduces the verified ReShade 6.8.0 x64 D3DMetal runtime patch. It checks the original DLL SHA-256 and refuses unrecognized input or an existing output file. The installer downloads and verifies supported ReShade builds before applying their version-specific patches.

The Subnautica 6.8.0 profile disables Generic Depth and Effect Runtime Sync to avoid a startup stall; depth-dependent effects are unavailable with Generic Depth disabled. `D3DMetalTest.fx` is a simple red/blue channel swap shader for manual testing.


## Quick install into a game

1. Back up the game folder.
2. Copy `dxgi.dll`, `ReShade.ini`, `ReShadePreset.ini`, and `reshade-shaders/` beside the game executable.
3. Rename the original graphics DLL to `dxgi.original.dll`; set `EnableProxyLibrary=1` and `ProxyLibrary` to that file in `ReShade.ini`.
4. Launch the game and check `ReShade.log` for `Successfully compiled`.

For another game, use its matching graphics DLL (`dxgi.dll`, `d3d11.dll`, or `d3d9.dll`). Keep the original DLL as the proxy backup. To uninstall, restore the original DLL and remove the ReShade files. Patches are version-specific.
