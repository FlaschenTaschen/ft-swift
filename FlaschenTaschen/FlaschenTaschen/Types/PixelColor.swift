// PixelColor.swift

import SwiftUI

nonisolated struct PixelColor: Identifiable, Hashable, Sendable {
    let id: Int
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    var color: Color {
        Color(red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0)
    }
}
