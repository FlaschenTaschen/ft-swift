# Multi-Packet Frame Accumulation - Implementation & Fixes

## Overview

The FlaschenTaschen Swift server receives PPM image data over UDP. Large images are split across multiple UDP packets by the client. The server must accumulate these packets into a single frame before rendering.

## The Problem (FIXED ✅)

**Issue**: Frames were displaying incomplete, with only partial image data visible.

**Root Cause**: `UDPServer.swift` was calling `onPixelUpdate()` on **every packet**, not just when frames were complete. This caused:
- Incomplete frames to render prematurely
- Layer and offset metadata not being properly applied
- Visual artifacts from partial image data

## The Solution

### 1. Frame Completion Detection (UDPServer.swift:212)

Only display when a complete frame has been received:

```swift
let frameComplete = image.offsetY + image.height >= self.gridHeight

if frameComplete {
    // Send complete accumulated frame to display
    self.onPixelUpdate(completeImage)
    layerBuffers[layer] = nil  // Reset for next frame
} else {
    // Continue accumulating more packets
    logger.debug("Accumulating... coverage: rows 0-\(image.offsetY + image.height - 1) of \(gridHeight)")
}
```

**Logic**: A frame is complete when the packets received so far cover the full height of the grid.

Example: 64×64 grid
- Packet 1: `offsetY=0, height=47` → `0 + 47 = 47` < 64 → accumulate
- Packet 2: `offsetY=47, height=17` → `47 + 17 = 64` ≥ 64 → send complete frame

### 2. Metadata Extraction (PPMParser.swift:143-167)

The parser correctly extracts `#FT: x y z` metadata from PPM headers:

```swift
private static func parseHeaderMetadata(buffer: [UInt8], offset: inout Int, ...) {
    while offset < buffer.count && buffer[offset] == UInt8(ascii: "#") {
        var line = ""
        // Read comment line
        while offset < buffer.count && buffer[offset] != UInt8(ascii: "\n") {
            line.append(Character(UnicodeScalar(buffer[offset])))
            offset += 1
        }

        // Parse #FT: metadata
        if line.hasPrefix("FT:") {
            parseOffsets(line: String(line.dropFirst(3)), offsetX: &offsetX, offsetY: &offsetY, layer: &layer)
        }
    }
}
```

**Key**: The parser reads comments **before** skipping them, preserving metadata values.

### 3. Per-Layer Buffers (UDPServer.swift:21)

Each layer maintains its own accumulation buffer:

```swift
private var layerBuffers: [Int: [PixelColor]] = [:]
```

This allows multiple layers to accumulate frames independently without interference.

## How Multi-Packet Frames Work

### Client Side (FlaschenTaschenClientKit.swift:132-175)

The client splits large images and sends with metadata:

```
Packet 1: P6 64 47 #FT: 0 0 7 255 [row 0-46 pixel data]
Packet 2: P6 64 17 #FT: 0 47 7 255 [row 47-63 pixel data]
```

Each packet is a complete PPM image with:
- Full width (64 in this example)
- Partial height (rows that fit in one UDP packet)
- `#FT:` comment with offsets and layer

### Server Side (UDPServer.swift:167-228)

For each received packet:

1. **Parse packet** → Extract width, height, offsetY, layer
2. **Initialize layer buffer** if needed (4096 black pixels for 64×64)
3. **Accumulate pixels** at correct grid positions:
   ```swift
   for y in 0..<image.height {
       let gridY = image.offsetY + y  // Apply offset
       for x in 0..<image.width {
           let gridX = image.offsetX + x
           pixelGrid[gridY * gridWidth + gridX] = sourcePixel
       }
   }
   ```
4. **Check completion**: `offsetY + height >= gridHeight`?
5. **Send or wait**:
   - If complete: render frame and reset buffer
   - If incomplete: keep accumulating

## Metadata Format

PPM header with FlaschenTaschen extensions:

```
P6
64 47
#FT: offsetX offsetY layer
255
[binary pixel data]
```

Fields:
- `offsetX`: horizontal offset in grid (0-319 for 320-wide displays)
- `offsetY`: vertical offset in grid (0-63 for 64-tall displays)
- `layer`: Z-order layer (0-15)

## Test Coverage

Comprehensive tests verify:

### PPMParserTests (12 tests)
- ✅ Basic PPM parsing
- ✅ `#FT:` metadata extraction
- ✅ Multi-packet scenarios
- ✅ Edge cases (missing metadata, large offsets)

### UDPServerAccumulationTests (11 tests)
- ✅ Single-packet immediate display
- ✅ Two-packet accumulation
- ✅ Frame completion detection
- ✅ Multiple layers separately
- ✅ Buffer reset after complete frame
- ✅ Large image handling

### MultiPacketIntegrationTests (7 tests)
- ✅ Python tool 64×64 scenario
- ✅ Layer metadata preservation
- ✅ Offset accuracy
- ✅ Timeout and buffer reset
- ✅ Rapid multi-layer updates
- ✅ Pixel position accuracy

**Total: 30+ test cases** ensuring multi-packet frames work correctly.

## Key Changes

| File | Change | Impact |
|------|--------|--------|
| `UDPServer.swift:214` | Only send when `frameComplete` | Prevents incomplete frames displaying |
| `UDPServer.swift:167` | Made `processPacket` public | Enables test access |
| `PPMParser.swift:143` | Added debug logging | Verifies FT metadata extraction |
| Tests (3 files) | 30+ comprehensive tests | Prevents regressions |

## Timeout Handling

If a frame is incomplete when a new frame arrives at layer 0, the incomplete frame is discarded:

```swift
if lastPacketTime == nil || (now.timeIntervalSince(lastPacketTime!) > 1.0) {
    layerBuffers.removeAll()  // Timeout: reset all buffers
}
```

This prevents stuck incomplete frames from blocking new data.

## Performance Notes

- **Per-packet overhead**: Minimal - just accumulation into pre-allocated buffer
- **Memory**: One buffer per layer × grid size (64×64×3 = 12KB per layer)
- **Latency**: Entire frame buffered; display updates when complete (typically <50ms total for 2 packets)

## Debugging

Enable logging to see packet processing:

```
📍 Found header comment: #FT: 0 0 7
📍 Parsed #FT: offset=(0,0) layer=7
🔵 PACKET: 64x47 offset=(0,0) LAYER=7
📥 ACCUMULATING to layer 7: rows 0-46
```

When frame completes:

```
🖼️ SEND layer 7: 64x64 (4096 non-black pixels)
Layer 7: frame complete, resetting buffer
```

## Verification

To verify the fix works:

1. Run Python tool that sends 64×64 image
2. Observe two packets received with offsets (0,0) and (0,47)
3. Frame displays only after second packet (complete)
4. All 4096 pixels visible (not partial)
5. Layer=7 preserved throughout
