// maze - Maze generation and solving animation
// Ported from maze.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "maze")

public struct MazeDemo: Sendable {
    struct Position {
        let x: Int
        let y: Int
    }

    // Color indices for maze generation
    private static let kColorBG: UInt8 = 0
    private static let kColorMaze: UInt8 = 1
    private static let kColorVisited: UInt8 = 2

    public struct Options: Sendable {
        public var hostname: String?
        public var layer = 2
        public var timeout = 60 * 60 * 24.0
        public var width = 45
        public var height = 35
        public var xoff = 0
        public var yoff = 0
        public var delay = 20
        public var fgColor = Color(r: 0xFF, g: 0xFF, b: 0xFF)
        public var visitedColor = Color(r: 0, g: 0, b: 0)
        public var bgColor = Color(r: 0, g: 0, b: 0)
        public var useFGColor = false
        public var useVisitedColor = false
        public var useBGColor = false

        public init(hostname: String? = nil, layer: Int = 2, timeout: Double = 60 * 60 * 24.0,
                    width: Int = 45, height: Int = 35, xoff: Int = 0, yoff: Int = 0, delay: Int = 20,
                    fgColor: Color = Color(r: 0xFF, g: 0xFF, b: 0xFF),
                    visitedColor: Color = Color(r: 0, g: 0, b: 0),
                    bgColor: Color = Color(r: 0, g: 0, b: 0),
                    useFGColor: Bool = false, useVisitedColor: Bool = false, useBGColor: Bool = false) {
            self.hostname = hostname
            self.layer = layer
            self.timeout = timeout
            self.width = width
            self.height = height
            self.xoff = xoff
            self.yoff = yoff
            self.delay = delay
            self.fgColor = fgColor
            self.visitedColor = visitedColor
            self.bgColor = bgColor
            self.useFGColor = useFGColor
            self.useVisitedColor = useVisitedColor
            self.useBGColor = useBGColor
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("maze: geometry=\(options.width, privacy: .public)x\(options.height, privacy: .public)+\(options.xoff, privacy: .public)+\(options.yoff, privacy: .public) layer=\(options.layer, privacy: .public) delay=\(options.delay, privacy: .public)ms")

        // Create pixel buffer
        var pixels = [UInt8](repeating: kColorBG, count: options.width * options.height)

        // Create rainbow palette for visited color cycling
        var palette = [Color](repeating: Color(), count: 256)
        colorGradient(start: 0, end: 31, r1: 255, g1: 0, b1: 255, r2: 0, g2: 0, b2: 255, palette: &palette)
        colorGradient(start: 32, end: 63, r1: 0, g1: 0, b1: 255, r2: 0, g2: 255, b2: 255, palette: &palette)
        colorGradient(start: 64, end: 95, r1: 0, g1: 255, b1: 255, r2: 0, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 96, end: 127, r1: 0, g1: 255, b1: 0, r2: 127, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 128, end: 159, r1: 127, g1: 255, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 160, end: 191, r1: 255, g1: 255, b1: 0, r2: 255, g2: 127, b2: 0, palette: &palette)
        colorGradient(start: 192, end: 223, r1: 255, g1: 127, b1: 0, r2: 255, g2: 0, b2: 0, palette: &palette)
        colorGradient(start: 224, end: 255, r1: 255, g1: 0, b1: 0, r2: 255, g2: 0, b2: 255, palette: &palette)

        canvas.clear()

        // Setup maze generation
        let maze_width = options.width / 2
        let maze_height = options.height / 2
        var cellStack: [Position] = []

        // Random initial position
        let start_pos = Position(x: randomInt(min: 0, max: maze_width - 1), y: randomInt(min: 0, max: maze_height - 1))
        cellStack.append(start_pos)

        // Animation loop
        let loop = AnimationLoop(timeout: options.timeout, delay: options.delay)
        var colorIndex = 0
        let fgColor = options.fgColor
        var visitedColor = options.visitedColor

        await loop.run { frameCount in
            // Generate one step of maze
            drawMazeStep(cellStack: &cellStack, px_width: options.width, px_height: options.height, pixels: &pixels)

            // Update visited color if cycling
            if !options.useVisitedColor {
                visitedColor = palette[colorIndex]
                colorIndex = (colorIndex + 1) % 256
            }

            // Copy pixel buffer to canvas
            for y in 0..<options.height {
                for x in 0..<options.width {
                    let pixelIndex = y * options.width + x
                    let color: Color
                    if pixels[pixelIndex] == kColorVisited {
                        color = visitedColor
                    } else if pixels[pixelIndex] == kColorMaze {
                        color = fgColor
                    } else {
                        color = options.bgColor
                    }
                    canvas.setPixel(x: x, y: y, color: color)
                }
            }

            // Send to display
            canvas.setOffset(x: options.xoff, y: options.yoff, z: options.layer)
            canvas.send()

            // Log progress every 500 frames
            if frameCount > 0 && frameCount % 500 == 0 {
                logger.info("maze: frame=\(frameCount) stack_size=\(cellStack.count)")
            }
        }

        // Clear canvas on exit
        canvas.clear()
        canvas.send()
    }

    private static func mazePos2PixelIndex(pos: Position, px_width: Int) -> Int {
        return ((pos.y * 2 * px_width) + (pos.x * 2))
    }

    private static func wallIndexBetweenPositions(pos1: Position, pos2: Position, px_width: Int) -> Int {
        return (((pos1.y + pos2.y) * px_width) + (pos1.x + pos2.x))
    }

    private static func drawMazeStep(cellStack: inout [Position], px_width: Int, px_height: Int, pixels: inout [UInt8]) {
        guard !cellStack.isEmpty else { return }

        let maze_width = (px_width / 2)
        let maze_height = (px_height / 2)
        let pos = cellStack[cellStack.count - 1]

        // Mark current position as maze
        let cur_idx = mazePos2PixelIndex(pos: pos, px_width: px_width)
        pixels[cur_idx] = kColorMaze

        // Find unvisited neighbors
        var neighbors: [Position] = []

        // Check up
        if pos.y > 0 {
            let temp_idx = (((pos.y - 1) * 2 * px_width) + (pos.x * 2))
            if pixels[temp_idx] == kColorBG {
                neighbors.append(Position(x: pos.x, y: pos.y - 1))
            }
        }
        // Check down
        if pos.y < maze_height - 1 {
            let temp_idx = (((pos.y + 1) * 2 * px_width) + (pos.x * 2))
            if pixels[temp_idx] == kColorBG {
                neighbors.append(Position(x: pos.x, y: pos.y + 1))
            }
        }
        // Check left
        if pos.x > 0 {
            let temp_idx = ((pos.y * 2 * px_width) + ((pos.x - 1) * 2))
            if pixels[temp_idx] == kColorBG {
                neighbors.append(Position(x: pos.x - 1, y: pos.y))
            }
        }
        // Check right
        if pos.x < maze_width - 1 {
            let temp_idx = ((pos.y * 2 * px_width) + ((pos.x + 1) * 2))
            if pixels[temp_idx] == kColorBG {
                neighbors.append(Position(x: pos.x + 1, y: pos.y))
            }
        }

        if !neighbors.isEmpty {
            // Pick a random neighbor
            let rand_idx = randomInt(min: 0, max: neighbors.count - 1)
            let neighbor = neighbors[rand_idx]

            // Draw wall between current and neighbor
            let wall_idx = wallIndexBetweenPositions(pos1: pos, pos2: neighbor, px_width: px_width)
            pixels[wall_idx] = kColorMaze

            // Push neighbor onto stack
            cellStack.append(neighbor)
        } else {
            // No unvisited neighbors - mark as visited and backtrack
            pixels[cur_idx] = kColorVisited
            cellStack.removeLast()

            // Draw wall to previous position
            if !cellStack.isEmpty {
                let pos2 = cellStack[cellStack.count - 1]
                let wall_idx = wallIndexBetweenPositions(pos1: pos, pos2: pos2, px_width: px_width)
                pixels[wall_idx] = kColorVisited
            }
        }
    }

    private static func colorGradient(
        start: Int,
        end: Int,
        r1: UInt8,
        g1: UInt8,
        b1: UInt8,
        r2: UInt8,
        g2: UInt8,
        b2: UInt8,
        palette: inout [Color]
    ) {
        let range = end - start
        for i in 0...range {
            let k = Float(i) / Float(range)
            let r = UInt8(Float(r1) + (Float(r2) - Float(r1)) * k)
            let g = UInt8(Float(g1) + (Float(g2) - Float(g1)) * k)
            let b = UInt8(Float(b1) + (Float(b2) - Float(b1)) * k)
            palette[start + i] = Color(r: r, g: g, b: b)
        }
    }
}
