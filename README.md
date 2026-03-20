# Flaschen Taschen — Swift Implementation

A unified Swift package for the **Flaschen Taschen** networked LED display system. Includes a complete client library, multiple content generators, interactive tools, and a debugger—all in one repo.

## About Flaschen Taschen

Flaschen Taschen is an art installation using 45×35 pixels (1,575 total) of programmable LEDs in a 9×7 grid of milk crates with aluminum-wrapped bottles. The original 2016 Noisebridge installation **won the Editor's Choice Award at Maker Faire**.

**Original Project:** https://github.com/hzeller/flaschen-taschen

## What's Included

This Swift package unifies four major components:

### 1. **Client Library** (`FlaschenTaschenClientKit`)

Core library for communicating with Flaschen Taschen displays over UDP.

- UDP protocol implementation (port 1337)
- PPM binary format support with FT metadata extensions
- Multi-layer rendering with transparency
- Automatic layer timeout management
- Configuration options for display geometry and frame rates

### 2. **Content Clients** (send-text, send-image, send-video)

Standalone command-line tools for sending content to displays:

- **send-text**: Display scrolling or static text with color palettes
- **send-image**: Load and display image files (PNG, JPEG, etc.)
- **send-video**: Stream video frames to the display in real-time

All clients support geometry, layer, and color options.

### 3. **Interactive Demos** (15+ programs)

Generative graphics and visualization demos, many ported from Carl Gorringe's [ft-demos](https://github.com/cgorringe/ft-demos) C++ collection:

**Simple Examples:**
- `simple-example` — Basic colored rectangles
- `simple-animation` — Animated shapes and transitions

**Generative Graphics:**
- `plasma` — Smooth plasma effect with color cycling
- `matrix` — Animated Matrix-style character rain
- `blur` — Gaussian blur visualization
- `quilt` — Procedural quilt pattern generator
- `firefly` — Wandering light particles with trails
- `depth` — 3D depth map visualization
- `random-dots` — Bouncing particle system

**Mathematical & Algorithmic:**
- `life` — Conway's Game of Life
- `fractal` — Julia set and Mandelbrot renderers
- `sierpinski` — Sierpinski triangle fractal
- `maze` — Procedural maze generator
- `lines` — Algorithmic line drawing patterns

**Text & Font Rendering:**
- `hack` — Rotating vector font with blur effect (ported from original hack demo)
- `words` — Streaming text display
- `nb-logo` — Noisebridge logo animation
- `sf-logo` — Sequoia Fabrica logo animation

**Audio & Interactive:**
- `midi` — MIDI keyboard input visualization
- `kbd2midi` — Computer keyboard to MIDI converter

**Display Control:**
- `black` — Clear display to black

### 4. **Debugger** (`ft-debugger`)

Interactive debugger for testing and development:

- Draws edges or fills entire display with colors
- Support several color palettes

## Building

### From Swift Package

```bash
cd ft-swift
./build.sh build      # Debug build
./build.sh release    # Optimized release build
./build.sh clean      # Clean build artifacts
./build.sh test       # Run tests
```

Binaries appear in `.build/debug/` or `.build/release/`.

### Or use Swift directly:

```bash
swift build           # Debug
swift build -c release  # Release
swift run <target>    # Run a specific target
```

### From Xcode (Mac app only)

```bash
open FlaschenTaschen/FlaschenTaschen.xcodeproj
```

Press **Cmd+R** to run the macOS server.

## Requirements

- **macOS 15+** (Sequoia or later)
- **Swift 6.2+**
- **Network access** to Flaschen Taschen display (physical hardware or local simulator)

## Quick Start

### 1. Start the Display Server (macOS)

```bash
open ../FlaschenTaschen/FlaschenTaschen.xcodeproj
# Build & run from Xcode, or:
# swift run ft-debugger
```

Listens on port 1337 by default.

### 2. Run a Demo

```bash
swift run plasma
swift run life
swift run hack
swift run matrix
```

Or run with custom geometry:

```bash
swift run plasma -g 45x35
swift run simple-example -h localhost
```

### 3. Send Custom Content

```bash
swift run send-text "Hello World" -c 255,0,0
swift run send-image myimage.png
swift run send-video myvideo.mp4
```

## Network Protocol

Standard Flaschen Taschen UDP protocol:

- **Port**: 1337
- **Format**: PPM binary (P6) with metadata extensions
- **Packet Structure**:

```
P6
<width> <height>
255
#FT: <x> <y> <z>
[binary RGB pixel data]
```

## Usage Examples

### Display rotating vector font

```bash
swift run hack "HACK" -d 25 -g 45x35
```

### Conway's Game of Life with custom timeout

```bash
swift run life -t 120
```

### Stream MIDI keyboard input

```bash
swift run midi -h 192.168.1.100
```

### All targets support:

- `-g <W>x<H>[+<X>+<Y>]` — Geometry (width×height+xoff+yoff)
- `-h <host>` — Display hostname/IP (default: localhost)
- `-l <layer>` — Layer 0-15 (default: 1)
- `-d <delay>` — Frame delay in milliseconds
- `-t <timeout>` — Timeout in seconds (auto-exit)
- `-p <palette>` — Color palette selection (demo-specific)

## Architecture

```
┌─────────────────────────────┐
│  FlaschenTaschenClientKit   │  Core library
│  (UDP + PPM + Rendering)    │
├─────────────────────────────┤
│ Content Generators          │
│ • send-text, send-image     │  Command-line
│ • send-video                │  clients
├─────────────────────────────┤
│ Interactive Demos           │
│ • plasma, life, matrix...   │  15+ demo
│ • hack, firefly, depth...   │  programs
├─────────────────────────────┤
│ ft-debugger                 │  Interactive
│ (Preview + Control)         │  development
└─────────────────────────────┘
```

## For Developers

### Using FlaschenTaschenClientKit in Your Project

```swift
import FlaschenTaschenClientKit

let canvas = UDPFlaschenTaschen(
    hostname: "localhost",
    width: 45,
    height: 35
)

for x in 0..<45 {
    for y in 0..<35 {
        canvas.setPixel(x: x, y: y, color: Color(r: 255, g: 0, b: 0))
    }
}

canvas.send()
```

### Creating New Demos

1. Add executable target to `Package.swift`
2. Create `Sources/<name>/main.swift`
3. Implement demo using `FlaschenTaschenClientKit`
4. Build: `swift run <name>`

See existing demos for patterns.

## License

MIT License — See LICENSE file for details.

## Credits

- **Original Flaschen Taschen**: Noisebridge community, 2016
- **Maker Faire 2016**: Editor's Choice Award
- **C++ Reference Implementation**: https://github.com/hzeller/flaschen-taschen
- **C++ Demos & Examples**: [ft-demos](https://github.com/cgorringe/ft-demos) by Carl Gorringe
- **This Swift Port**: Unified package with client library, demos (ported from ft-demos), and interactive tools

## Further Reading

- [Original Project](https://github.com/hzeller/flaschen-taschen)
- [Flaschen Taschen Wiki](https://noisebridge.net/wiki/Flaschen_Taschen)
- [Network Protocol](https://github.com/hzeller/flaschen-taschen/blob/master/doc/protocols.md)
- [API Examples](https://github.com/hzeller/flaschen-taschen/tree/master/examples-api-use)
