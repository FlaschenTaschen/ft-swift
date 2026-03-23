# Packets and frames (client → server)

This describes how the **Swift client** (`FlaschenTaschenClientKit`, type `UDPFlaschenTaschen`) turns a drawn canvas into one or more **UDP datagrams** and how that lines up with what the **display server** expects. Implementation: `Sources/FlaschenTaschenClientKit/FlaschenTaschenClientKit.swift`.

## Mental model

- One **logical frame** is whatever you have drawn in the canvas when you call `send()`.
- If the raw PPM for that image is larger than the allowed UDP payload, `send()` **splits it into multiple datagrams**. Each datagram is still a **valid P6 PPM**: its own width, height, header, and pixel payload.
- The server **does not** reassemble byte streams. It **merges rectangles** into a per-layer grid using `#FT:` placement metadata on each packet.

## Transport

- **Protocol**: UDP, connected socket to the host (default `FT_DISPLAY` or `localhost`) on **port 1337** (`openFlaschenTaschenSocket`).
- **Sending**: `send()` uses `sendto` on that file descriptor; packets are emitted **in row order** (top chunk first, then the next vertical slice, and so on).

## Maximum datagram size

`getMaxUDPSize()` picks the cap for chunking, in order:

1. Environment variable **`FT_UDP_SIZE`** (integer bytes), if set  
2. Else **`SO_SNDBUF`** from a probe datagram socket  
3. Else **65507** (typical IPv4 UDP max payload)

`UDPFlaschenTaschen` reserves **`headerReserve` = 64** bytes for the ASCII header when computing how many **full rows** fit per packet:

```text
maxRowsPerPacket = (maxUDPSize - 64) / (3 * canvasWidth)
```

At least one row must fit; otherwise `initializeBuffer` preconditions fail.

## Canvas and offsets

- The canvas is a fixed **width × height** RGB buffer (3 bytes per pixel).
- **`setOffset(x:y:z:)`** sets placement on the **display grid** and the **layer** (z):
  - **x, y**: top-left of this canvas in grid coordinates.
  - **z**: layer index (sent as the third value in `#FT:`).

These apply to **every** chunk in the next `send()`.

## What each UDP packet contains

For each vertical slice, the client builds:

1. **PPM header** (ASCII), for example:

   ```text
   P6
   <fullCanvasWidth> <rowsThisChunk>
   #FT: <offsetX> <offsetYForThisChunk> <layer>
   255
   
   ```

2. **Binary pixel data**: `rowsThisChunk × canvasWidth × 3` bytes, **row-major RGB**, max channel value 255 — the next rows from the internal buffer starting at `chunkRowOffset`.

Details from `send()`:

- **`rowsThisChunk`** is `min(maxRowsPerPacket, height_ - chunkRowOffset)` so the last packet carries any remainder rows.
- **`#FT:`** uses `offsetX`, `offsetY + chunkRowOffset`, and `offsetZ` so each chunk’s PPM **height** matches its payload, and **y** tells the server which grid row that slice starts at.

Example for a 64-wide, 64-tall canvas at grid (0,0), layer 7, split into two packets:

- Packet 1: `P6\n64 47\n#FT: 0 0 7\n255\n` + 64×47 RGB  
- Packet 2: `P6\n64 17\n#FT: 0 47 7\n255\n` + 64×17 RGB  

Same **width** and **layer** on every chunk; **height** and **`#FT:` y** change per chunk.

## Internal buffer vs. on-the-wire header

The in-memory canvas uses a minimal header (`P6`, full width/height, `255`, then pixels). **`#FT:` is not stored there**; it is **inserted only when building each outbound packet** so each datagram is self-describing for the parser.

## Contract with the Swift display server

The server accumulates into a **per-layer** buffer and calls the UI when it decides the frame is **vertically complete** for that layer: it requires the **last processed packet** to satisfy `offsetY + height ≥ gridHeight` (where `offsetY`/`height` come from that packet’s parsed PPM and `#FT:`).

So for a **full-grid** update on a display of height `H`, a typical client uses a canvas with **height `H`**, **`setOffset(x: 0, y: 0, z: …)`**, and `send()` — the final chunk’s geometry then reaches the bottom row of the grid.

If you send a **shorter** image (smaller canvas height) without covering the grid bottom under that rule, the server may **not** treat the frame as complete and may not flush to the display the same way. Design partial-frame behavior with that server rule in mind.

## Ordering and timing

- The client sends chunks **sequentially** in one `send()` call.
- UDP does not guarantee order; in practice, same-host LAN sends are usually in order. The server’s **timeout** (see server / `PacketChunking.md`) can clear partial accumulation if packets are too far apart in time.

## API summary

| Step | Action |
|------|--------|
| Open socket | `openFlaschenTaschenSocket(hostname?)` → fd, or `-1` on failure |
| Create canvas | `UDPFlaschenTaschen(fileDescriptor:width:height:)` |
| Position / layer | `setOffset(x:y:z:)` |
| Draw | `setPixel`, `clear`, `fill`, etc. |
| Transmit | `send()` — one or more UDP packets, automatically chunked |

`clone()` copies buffer and offsets for another canvas sharing the same fd and dimensions.
