// PixelColor.swift

import Foundation
import SwiftUI

public nonisolated struct PixelColor: Identifiable, Hashable, Sendable {
    public let id: Int
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(id: Int, red: UInt8, green: UInt8, blue: UInt8) {
        self.id = id
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var color: Color {
        Color(red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0)
    }
}
