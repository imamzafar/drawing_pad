# Drawing Pad (macOS)

Native Intel macOS drawing pad inspired by the provided HTML “Infinite Stylus Canvas”. The app lets you sketch on an endless canvas, pan with the space bar or hand tool, zoom, erase, change ink/background colours, and export to PNG — no pen press required once drawing mode is toggled with `D`, just hover to draw.

## Features
- Toggle drawing with `D`; drawing immediately tracks pointer hover (no click required) when enabled.
- Hand tool and space-bar panning with smooth offset/zoom controls.
- Adjustable pen and eraser sizes, ink colour picker, and preset/custom background colours.
- On-canvas eraser preview sized to the current eraser diameter.
- Clear canvas and PNG export that crops to the drawn content (with padding) while also persisting strokes, colours, and tool sizes between sessions.

## Requirements
- macOS 13.0 or newer running on Intel hardware.
- Xcode 15 or Swift 6 toolchain (Swift Package Manager) for building.

## Building & Running

### Option 1 — Xcode
1. Open `Package.swift` in Xcode.
2. Select the `DrawingPad` scheme, choose the “My Mac” destination, and run (`⌘R`).  
   Xcode will build the `.app` bundle and launch the drawing pad.

### Option 2 — Command line
Swift Package Manager can launch the SwiftUI app directly:

```bash
cd /path/to/drawing_pad
CLANG_MODULE_CACHE_PATH=$(pwd)/.clangModuleCache swift run --product DrawingPad
```

Setting `CLANG_MODULE_CACHE_PATH` keeps module caches inside the project (useful if your environment restricts writes elsewhere).

### Bundled build output
- `swift build --product DrawingPad` (with the same `CLANG_MODULE_CACHE_PATH` prefix) places the executable under `.build/<triple>/debug/DrawingPad`.
- You can wrap the binary in a `.app` via Xcode, or continue launching with `swift run`.

## Creating Downloadable Releases

### Local packaging script
Run the helper script to produce a signed `.app` bundle and zipped archive for the current or specified architecture:

```bash
# Intel build (default if you run on an Intel Mac)
Scripts/package_app.sh --arch x86_64 --version 1.0.0

# Apple Silicon build (run on an M-series Mac)
Scripts/package_app.sh --arch arm64 --version 1.0.0
```

The script:
- Builds `DrawingPad` in Release configuration for the requested architecture.
- Assembles `DrawingPad.app` with a minimal `Info.plist` and ad-hoc code signature.
- Produces `dist/DrawingPad-<version>-<arch>.zip`, ready to upload as a release asset.

Run the script separately on an Intel and an Apple Silicon machine to offer both downloads, or combine the two binaries with `lipo` if you prefer a universal bundle.

### GitHub release automation (optional)
A workflow can generate tagged release artifacts for both architectures. After pushing a tag (`git tag v1.0.0 && git push origin v1.0.0`), GitHub actions on macOS-13 (Intel) and macOS-14 (Apple Silicon) will invoke the packaging script and attach `DrawingPad-<version>-x86_64.zip` and `DrawingPad-<version>-arm64.zip` to the release.

## Controls Recap
- `D` — Toggle drawing (hover to draw while active).
- `Space` — Temporarily pan; click-drag while held for precise moves.
- **Hand** button — Persistent panning mode.
- **Eraser** — Toggle erasing (size adjustable).
- **Zoom ±** — Scale the canvas.
- **Clear** — Remove all strokes.
- **Save** — Export PNG trimmed to artwork bounds.

Enjoy sketching! If you run into build issues, ensure Xcode command line tools are installed (`xcode-select --install`) and that module cache paths resolve inside a writable directory.
