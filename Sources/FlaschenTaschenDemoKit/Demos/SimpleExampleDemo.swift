// Simple example - Sets two static points on the display
// Red dot at (0,0) and blue dot at (5,5)

import Foundation

public struct SimpleExampleDemo: Sendable {
    public struct Options: Sendable {
        public var hostname: String?
        public var width = 25
        public var height = 20

        public init(hostname: String? = nil, width: Int = 25, height: Int = 20) {
            self.hostname = hostname
            self.width = width
            self.height = height
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        // Set two pixels: red at (0,0) and blue at (5,5)
        canvas.setPixel(x: 0, y: 0, color: Color(r: 255, g: 0, b: 0))
        canvas.setPixel(x: 5, y: 5, color: Color(r: 0, g: 0, b: 255))

        // Send the framebuffer
        canvas.send()
    }
}
