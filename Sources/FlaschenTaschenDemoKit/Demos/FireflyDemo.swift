// Firefly - Animated firefly pattern swarms
// Ported from firefly by Dana Sniezko
// https://github.com/danasf/firefly/

import Foundation
import os.log

private let logger = Logger(subsystem: Logging.subsystem, category: "firefly")

public enum FireflyPattern: String, CaseIterable, Sendable {
    case firefly = "firefly"
    case rainbow = "rainbow"
    case wave = "wave"
    case bounce = "bounce"
    case twinkle = "twinkle"
    case pulse = "pulse"
    case chase = "chase"
    case matrix = "matrix"

    public static let allNames = FireflyPattern.allCases.map { $0.rawValue }.joined(separator: ", ")
}

struct Firefly: Sendable {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var glowCounter: Int = 0
    var hue: Int

    private static let PI = Double.pi

    mutating func update(width: Int, height: Int) {
        glowCounter += 1

        // Move slowly with wraparound
        x += vx
        y += vy

        if x < 0 { x += Double(width) }
        if x >= Double(width) { x -= Double(width) }
        if y < 0 { y += Double(height) }
        if y >= Double(height) { y -= Double(height) }
    }

    func getPosition() -> (x: Int, y: Int) {
        return (Int(x), Int(y))
    }

    func getColor() -> Color {
        // Brightness pulses with sine wave, clamped to 0-255
        let sineValue = sin((2 * Self.PI / 30) * Double(glowCounter)) * 127.5 + 127.5
        let brightness = max(0, min(255, Int(sineValue)))

        return hsvToRGB(hue: hue, saturation: 255, brightness: brightness)
    }

    // Convert HSV to RGB (ported from Dana's code)
    private func hsvToRGB(hue: Int, saturation: Int, brightness: Int) -> Color {
        if saturation == 0 {
            return Color(r: UInt8(brightness), g: UInt8(brightness), b: UInt8(brightness))
        }

        let base = ((255 - saturation) * brightness) >> 8
        let hueSegment = hue / 60
        let hueRemainder = hue % 60

        let val = brightness
        let r = val - base

        switch hueSegment {
        case 0:
            let g = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(val), g: UInt8(g), b: UInt8(base))
        case 1:
            let r_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(r_component), g: UInt8(val), b: UInt8(base))
        case 2:
            let b = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(base), g: UInt8(val), b: UInt8(b))
        case 3:
            let g_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(base), g: UInt8(g_component), b: UInt8(val))
        case 4:
            let r_component = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(r_component), g: UInt8(base), b: UInt8(val))
        default: // case 5
            let g_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(val), g: UInt8(base), b: UInt8(g_component))
        }
    }
}

struct BouncingLight: Sendable {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var hue: Int

    mutating func update(width: Int, height: Int) {
        x += vx
        y += vy

        if x <= 0 || x >= Double(width - 1) {
            vx = -vx
            x = max(0, min(Double(width - 1), x))
        }
        if y <= 0 || y >= Double(height - 1) {
            vy = -vy
            y = max(0, min(Double(height - 1), y))
        }
    }

    func getColor(brightness: Int) -> Color {
        hsvToRGB(hue: hue, saturation: 255, brightness: brightness)
    }

    private func hsvToRGB(hue: Int, saturation: Int, brightness: Int) -> Color {
        if saturation == 0 {
            return Color(r: UInt8(brightness), g: UInt8(brightness), b: UInt8(brightness))
        }

        let base = ((255 - saturation) * brightness) >> 8
        let hueSegment = hue / 60
        let hueRemainder = hue % 60
        let val = brightness
        let r = val - base

        switch hueSegment {
        case 0:
            let g = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(val), g: UInt8(g), b: UInt8(base))
        case 1:
            let r_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(r_component), g: UInt8(val), b: UInt8(base))
        case 2:
            let b = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(base), g: UInt8(val), b: UInt8(b))
        case 3:
            let g_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(base), g: UInt8(g_component), b: UInt8(val))
        case 4:
            let r_component = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(r_component), g: UInt8(base), b: UInt8(val))
        default: // case 5
            let g_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(val), g: UInt8(base), b: UInt8(g_component))
        }
    }
}

public struct FireflyDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var patternName: String?
        public var numLights: Int = 5
        public var patternSwitchSeconds: Int = 15

        public init(standardOptions: StandardOptions, patternName: String? = nil, numLights: Int = 5, patternSwitchSeconds: Int = 15) {
            self.standardOptions = standardOptions
            self.patternName = patternName
            self.numLights = numLights
            self.patternSwitchSeconds = patternSwitchSeconds
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        canvas.clear()

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var frameCount = 0
        var currentPattern = parsePattern(options.patternName) ?? .firefly
        var lastPatternChangeFrame = 0

        // Initialize pattern state
        var fireflies: [Firefly] = []
        var bouncingLights: [BouncingLight] = []
        var rainbowOffset = 0
        var waveOffset = 0
        var twinkleFrame = 0
        var chaseOffset = 0

        // Helper to initialize fireflies
        func initFireflies() {
            fireflies = []
            for i in 0..<options.numLights {
                fireflies.append(Firefly(
                    x: Double(Int.random(in: 0..<options.standardOptions.width)),
                    y: Double(Int.random(in: 0..<options.standardOptions.height)),
                    vx: Double.random(in: -0.05...0.05),
                    vy: Double.random(in: -0.05...0.05),
                    hue: (359 / options.numLights) * i
                ))
            }
        }

        // Helper to initialize bouncing lights
        func initBouncing() {
            bouncingLights = []
            for i in 0..<options.numLights {
                bouncingLights.append(BouncingLight(
                    x: Double(Int.random(in: 0..<options.standardOptions.width)),
                    y: Double(Int.random(in: 0..<options.standardOptions.height)),
                    vx: Double.random(in: -0.1...0.1),
                    vy: Double.random(in: -0.1...0.1),
                    hue: (359 / options.numLights) * i
                ))
            }
        }

        // Initialize based on starting pattern
        if currentPattern == .bounce {
            initBouncing()
        } else {
            initFireflies()
        }

        await loop.run { _ in
            frameCount += 1

            // Change pattern every N seconds (auto mode cycles through all patterns)
            let framesPerSecond = 1000 / options.standardOptions.delay  // approximate
            let framesBetweenPatternChanges = options.patternSwitchSeconds * framesPerSecond
            if options.patternName == "auto" && frameCount - lastPatternChangeFrame >= framesBetweenPatternChanges {
                currentPattern = FireflyPattern.allCases.randomElement() ?? .firefly
                lastPatternChangeFrame = frameCount
                logger.info("Pattern changed to: \(currentPattern.rawValue, privacy: .public)")

                // Reinitialize bounce pattern with new lights
                if currentPattern == .bounce {
                    initBouncing()
                }
            }

            canvas.clear()

            // Always update firefly positions for all patterns
            for i in fireflies.indices {
                fireflies[i].update(width: options.standardOptions.width, height: options.standardOptions.height)
            }

            // Render current pattern (all patterns only draw at firefly positions)
            switch currentPattern {
            case .firefly:
                // Glowing pulsing lights with shifting hues
                for firefly in fireflies {
                    let pos = firefly.getPosition()
                    canvas.setPixel(x: pos.x, y: pos.y, color: firefly.getColor())
                }

            case .rainbow:
                // Cycling rainbow colors on each light
                rainbowOffset = (rainbowOffset + 1) % 256
                for (i, firefly) in fireflies.enumerated() {
                    let pos = firefly.getPosition()
                    let hue = (rainbowOffset + i * (360 / options.numLights)) % 360
                    let color = hsvToRGB(hue: hue, saturation: 255, brightness: 255)
                    canvas.setPixel(x: pos.x, y: pos.y, color: color)
                }

            case .wave:
                // Wave effect on each light based on position
                waveOffset = (waveOffset + 1) % 256
                for firefly in fireflies {
                    let pos = firefly.getPosition()
                    let wave = sin(Double(pos.x + waveOffset) * 0.1) * 127.5 + 127.5
                    let hue = Int(wave * 359.0 / 255.0)
                    let color = hsvToRGB(hue: hue, saturation: 255, brightness: Int(wave))
                    canvas.setPixel(x: pos.x, y: pos.y, color: color)
                }

            case .bounce:
                // Bouncing lights with pulsing brightness
                for i in bouncingLights.indices {
                    bouncingLights[i].update(width: options.standardOptions.width, height: options.standardOptions.height)
                }
                for light in bouncingLights {
                    let brightness = Int(sin(Double(frameCount) * 0.05) * 127.5 + 127.5)
                    canvas.setPixel(x: Int(light.x), y: Int(light.y), color: light.getColor(brightness: brightness))
                }

            case .twinkle:
                // Random twinkling of lights
                twinkleFrame = (twinkleFrame + 1) % 30
                for (i, firefly) in fireflies.enumerated() {
                    let pos = firefly.getPosition()
                    let brightness = max(0, 255 - ((twinkleFrame + i * 3) % 30) * 8)
                    let color = hsvToRGB(hue: (i * (359 / options.numLights)), saturation: 255, brightness: brightness)
                    canvas.setPixel(x: pos.x, y: pos.y, color: color)
                }

            case .pulse:
                // All lights pulse together
                let brightness = Int(sin(Double(frameCount) * 0.05) * 127.5 + 127.5)
                for (i, firefly) in fireflies.enumerated() {
                    let pos = firefly.getPosition()
                    let hue = (frameCount / 4 + i * (359 / options.numLights)) % 360
                    let color = hsvToRGB(hue: hue, saturation: 255, brightness: brightness)
                    canvas.setPixel(x: pos.x, y: pos.y, color: color)
                }

            case .chase:
                // Lights chase each other
                chaseOffset = (chaseOffset + 1) % 360
                for (i, firefly) in fireflies.enumerated() {
                    let pos = firefly.getPosition()
                    let angle = (chaseOffset + i * (360 / options.numLights)) % 360
                    let brightness = Int(sin(Double(angle) * Double.pi / 180.0) * 127.5 + 127.5)
                    let color = hsvToRGB(hue: angle, saturation: 255, brightness: brightness)
                    canvas.setPixel(x: pos.x, y: pos.y, color: color)
                }

            case .matrix:
                // Digital rain effect - lights flicker like matrix code
                for (i, firefly) in fireflies.enumerated() {
                    let pos = firefly.getPosition()
                    let flicker = (frameCount + i * 5) % 20
                    let brightness = flicker < 15 ? 255 : 100
                    let color = hsvToRGB(hue: 120, saturation: 255, brightness: brightness)
                    canvas.setPixel(x: pos.x, y: pos.y, color: color)
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }

    private static func parsePattern(_ name: String?) -> FireflyPattern? {
        guard let name = name else { return nil }
        return FireflyPattern(rawValue: name)
    }

    private static func hsvToRGB(hue: Int, saturation: Int, brightness: Int) -> Color {
        if saturation == 0 {
            return Color(r: UInt8(brightness), g: UInt8(brightness), b: UInt8(brightness))
        }

        let base = ((255 - saturation) * brightness) >> 8
        let hueSegment = hue / 60
        let hueRemainder = hue % 60
        let val = brightness
        let r = val - base

        switch hueSegment {
        case 0:
            let g = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(val), g: UInt8(g), b: UInt8(base))
        case 1:
            let r_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(r_component), g: UInt8(val), b: UInt8(base))
        case 2:
            let b = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(base), g: UInt8(val), b: UInt8(b))
        case 3:
            let g_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(base), g: UInt8(g_component), b: UInt8(val))
        case 4:
            let r_component = (r * hueRemainder) / 60 + base
            return Color(r: UInt8(r_component), g: UInt8(base), b: UInt8(val))
        default: // case 5
            let g_component = (r * (60 - hueRemainder)) / 60 + base
            return Color(r: UInt8(val), g: UInt8(base), b: UInt8(g_component))
        }
    }
}
