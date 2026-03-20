// Color palette and gradient utilities for Flaschen Taschen demos

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "Color")

// MARK: - Gradient Generation

/// Generate a color gradient between two colors and store in palette
public nonisolated func colorGradient(
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
    let count = end - start
    guard count > 0 else { return }

    for i in 0...count {
        let k = Float(i) / Float(count)
        palette[start + i].r = UInt8(Float(r1) + (Float(r2) - Float(r1)) * k)
        palette[start + i].g = UInt8(Float(g1) + (Float(g2) - Float(g1)) * k)
        palette[start + i].b = UInt8(Float(b1) + (Float(b2) - Float(b1)) * k)
    }
}

// MARK: - Standard Palettes

public enum PaletteType: Int, CaseIterable {
    case rainbow = 0
    case nebula = 1
    case fire = 2
    case bluegreen = 3
    case colorful = 4
    case magma = 5
    case inferno = 6
    case plasma = 7
    case viridis = 8

    public static func paletteType(for name: String? = nil) -> PaletteType {
        guard let name else {
            logger.debug("Defaulting to Rainbow")

            let rawValue = randomInt(min: PaletteType.rainbow.rawValue,
                                     max: PaletteType.viridis.rawValue)
            let paletteType = PaletteType(rawValue: rawValue) ?? .rainbow
            return paletteType
        }

        logger.log("Palette: \(name)")

        switch name {
        case "rainbow": return .rainbow
        case "nebula": return .nebula
        case "fire": return .fire
        case "bluegreen": return .bluegreen
        case "colorful": return .colorful
        case "magma": return .magma
        case "inferno": return .inferno
        case "plasma": return .plasma
        case "viridis": return .viridis
        default: return .rainbow
        }
    }

    /// Apply this palette to a 256-color palette array
    public func apply(to palette: inout [Color]) {
        switch self {
        case .rainbow:
            applyRainbowPalette(to: &palette)
        case .nebula:
            applyNebulaPalette(to: &palette)
        case .fire:
            applyFirePalette(to: &palette)
        case .bluegreen:
            applyBlueGreenPalette(to: &palette)
        case .colorful:
            applyColorfulPalette(to: &palette)
        case .magma:
            applyMagmaPalette(to: &palette)
        case .inferno:
            applyInfernoPalette(to: &palette)
        case .plasma:
            applyPlasmaPalette(to: &palette)
        case .viridis:
            applyViridisPalette(to: &palette)
        }
    }

    public var description: String {
        switch self {
        case .rainbow: return "Rainbow"
        case .nebula: return "Nebula"
        case .fire: return "Fire"
        case .bluegreen: return "Bluegreen"
        case .colorful: return "Colorful"
        case .magma: return "Magma"
        case .inferno: return "Inferno"
        case .plasma: return "Plasma"
        case .viridis: return "Viridis"
        }
    }
}

private func applyColorfulPalette(to palette: inout [Color]) {
    // Red-dominant colorful palette: black -> red -> magenta -> cyan -> white
    colorGradient(start: 0, end: 63, r1: 0, g1: 0, b1: 0, r2: 255, g2: 0, b2: 0, palette: &palette)
    colorGradient(start: 64, end: 127, r1: 255, g1: 0, b1: 0, r2: 255, g2: 0, b2: 255, palette: &palette)
    colorGradient(start: 128, end: 191, r1: 255, g1: 0, b1: 255, r2: 0, g2: 255, b2: 255, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 0, g1: 255, b1: 255, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyNebulaPalette(to palette: inout [Color]) {
    colorGradient(start: 0, end: 31, r1: 1, g1: 1, b1: 1, r2: 0, g2: 0, b2: 127, palette: &palette)
    colorGradient(start: 32, end: 95, r1: 0, g1: 0, b1: 127, r2: 127, g2: 0, b2: 255, palette: &palette)
    colorGradient(start: 96, end: 159, r1: 127, g1: 0, b1: 255, r2: 255, g2: 0, b2: 0, palette: &palette)
    colorGradient(start: 160, end: 191, r1: 255, g1: 0, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 255, g1: 255, b1: 255, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyFirePalette(to palette: inout [Color]) {
    colorGradient(start: 0, end: 31, r1: 1, g1: 1, b1: 1, r2: 0, g2: 0, b2: 127, palette: &palette)
    colorGradient(start: 32, end: 95, r1: 0, g1: 0, b1: 127, r2: 255, g2: 0, b2: 0, palette: &palette)
    colorGradient(start: 96, end: 159, r1: 255, g1: 0, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
    colorGradient(start: 160, end: 191, r1: 255, g1: 255, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 255, g1: 255, b1: 255, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyBlueGreenPalette(to palette: inout [Color]) {
    colorGradient(start: 0, end: 31, r1: 1, g1: 1, b1: 1, r2: 0, g2: 0, b2: 127, palette: &palette)
    colorGradient(start: 32, end: 95, r1: 0, g1: 0, b1: 127, r2: 0, g2: 127, b2: 255, palette: &palette)
    colorGradient(start: 96, end: 159, r1: 0, g1: 127, b1: 255, r2: 0, g2: 255, b2: 0, palette: &palette)
    colorGradient(start: 160, end: 191, r1: 0, g1: 255, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 255, g1: 255, b1: 255, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyRainbowPalette(to palette: inout [Color]) {
    // Rainbow from red -> yellow -> green -> cyan -> blue -> magenta
    colorGradient(start: 0, end: 42, r1: 255, g1: 0, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
    colorGradient(start: 43, end: 85, r1: 255, g1: 255, b1: 0, r2: 0, g2: 255, b2: 0, palette: &palette)
    colorGradient(start: 86, end: 128, r1: 0, g1: 255, b1: 0, r2: 0, g2: 255, b2: 255, palette: &palette)
    colorGradient(start: 129, end: 170, r1: 0, g1: 255, b1: 255, r2: 0, g2: 0, b2: 255, palette: &palette)
    colorGradient(start: 171, end: 213, r1: 0, g1: 0, b1: 255, r2: 255, g2: 0, b2: 255, palette: &palette)
    colorGradient(start: 214, end: 255, r1: 255, g1: 0, b1: 255, r2: 255, g2: 0, b2: 0, palette: &palette)
}

private func applyMagmaPalette(to palette: inout [Color]) {
    // Magma: black -> purple -> red -> yellow -> white
    colorGradient(start: 0, end: 63, r1: 13, g1: 11, b1: 30, r2: 75, g2: 0, b2: 130, palette: &palette)
    colorGradient(start: 64, end: 127, r1: 75, g1: 0, b1: 130, r2: 255, g2: 0, b2: 0, palette: &palette)
    colorGradient(start: 128, end: 191, r1: 255, g1: 0, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 255, g1: 255, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyInfernoPalette(to palette: inout [Color]) {
    // Inferno: black -> purple -> orange -> yellow -> white
    colorGradient(start: 0, end: 63, r1: 0, g1: 0, b1: 4, r2: 87, g2: 16, b2: 121, palette: &palette)
    colorGradient(start: 64, end: 127, r1: 87, g1: 16, b1: 121, r2: 224, g2: 92, b2: 14, palette: &palette)
    colorGradient(start: 128, end: 191, r1: 224, g1: 92, b1: 14, r2: 253, g2: 231, b2: 37, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 253, g1: 231, b1: 37, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyPlasmaPalette(to palette: inout [Color]) {
    // Plasma: dark purple -> magenta -> bright cyan -> yellow -> white
    colorGradient(start: 0, end: 63, r1: 13, g1: 0, b1: 51, r2: 136, g2: 0, b2: 136, palette: &palette)
    colorGradient(start: 64, end: 127, r1: 136, g1: 0, b1: 136, r2: 0, g2: 255, b2: 255, palette: &palette)
    colorGradient(start: 128, end: 191, r1: 0, g1: 255, b1: 255, r2: 255, g2: 255, b2: 0, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 255, g1: 255, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
}

private func applyViridisPalette(to palette: inout [Color]) {
    // Viridis: dark blue -> cyan -> green -> yellow
    colorGradient(start: 0, end: 63, r1: 68, g1: 1, b1: 84, r2: 59, g2: 82, b2: 139, palette: &palette)
    colorGradient(start: 64, end: 127, r1: 59, g1: 82, b1: 139, r2: 33, g2: 145, b2: 140, palette: &palette)
    colorGradient(start: 128, end: 191, r1: 33, g1: 145, b1: 140, r2: 253, g2: 231, b2: 37, palette: &palette)
    colorGradient(start: 192, end: 255, r1: 253, g1: 231, b1: 37, r2: 255, g2: 255, b2: 255, palette: &palette)
}

// MARK: - Palette Cycling

/// Cycle to the next palette type
public nonisolated func nextPaletteType(_ current: PaletteType) -> PaletteType {
    let allCases = PaletteType.allCases
    guard let index = allCases.firstIndex(of: current) else { return .nebula }
    let nextIndex = (allCases.index(after: index) < allCases.endIndex) ? allCases.index(after: index) : allCases.startIndex
    return allCases[nextIndex]
}

/// Get palette type by integer, cycling if out of range
public nonisolated func getPaletteType(rawValue: Int) -> PaletteType {
    if let palette = PaletteType(rawValue: rawValue) {
        return palette
    }
    // Cycle through valid values
    let allCases = PaletteType.allCases
    let index = (rawValue - 1) % allCases.count
    return allCases[index]
}
