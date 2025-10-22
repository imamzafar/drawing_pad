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

## Controls Recap
- `D` — Toggle drawing (hover to draw while active).
- `Space` — Temporarily pan; click-drag while held for precise moves.
- **Hand** button — Persistent panning mode.
- **Eraser** — Toggle erasing (size adjustable).
- **Zoom ±** — Scale the canvas.
- **Clear** — Remove all strokes.
- **Save** — Export PNG trimmed to artwork bounds.

Enjoy sketching! If you run into build issues, ensure Xcode command line tools are installed (`xcode-select --install`) and that module cache paths resolve inside a writable directory.
