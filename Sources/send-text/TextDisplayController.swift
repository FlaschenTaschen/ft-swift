// Text display controller - handles scrolling and rendering modes

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendText")

actor TextDisplayController {
    private let canvas: UDPFlaschenTaschen
    private let font: BDFFont
    private let args: TextCommandLineArgs
    private var shouldStop = false

    init(canvas: UDPFlaschenTaschen, font: BDFFont, args: TextCommandLineArgs) {
        self.canvas = canvas
        self.font = font
        self.args = args
    }

    nonisolated func stop() {
        // Signal handling would set this
    }

    func displayText() async {
        let width = canvas.width
        let height = canvas.height

        // Determine actual display height
        let displayHeight = args.geometry.height > 0 ? args.geometry.height : height

        // Calculate Y position (vertically centered)
        let yPos = (displayHeight - font.fontHeight()) / 2 + font.fontBaseline()
        let xPos = (width - (font.characterWidth(87) > 0 ? font.characterWidth(87) : 8)) / 2

        if args.scrollDelayMs > 0 {
            // Scrolling mode
            if args.verticalMode {
                await displayVerticalScroll(yPos: yPos, xPos: xPos)
            } else {
                await displayHorizontalScroll(yPos: yPos)
            }
        } else {
            // Static display
            displayStatic(yPos: yPos, xPos: xPos)
        }

        // Clear display if not scrolling forever
        if args.geometry.layer > 0 && args.scrollDelayMs > 0 {
            canvas.clear()
            canvas.send()
        }
    }

    private func displayHorizontalScroll(yPos: Int) async {
        let width = canvas.width
        let textWidth = measureTextWidth(args.text)

        var continue_loop = true
        while continue_loop && !shouldStop {
            for s in 0...(textWidth + width) {
                if shouldStop {
                    continue_loop = false
                    break
                }

                let scrollPos = width - s

                canvas.fill(color: args.backgroundColor)

                if let outline = args.outlineColor {
                    _ = drawText(
                        canvas: canvas,
                        font: font,
                        x: scrollPos,
                        y: yPos,
                        color: outline,
                        backgroundColor: nil,
                        text: args.text,
                        letterSpacing: args.letterSpacing - 2
                    )
                }

                _ = drawText(
                    canvas: canvas,
                    font: font,
                    x: scrollPos + 1,
                    y: yPos,
                    color: args.textColor,
                    backgroundColor: nil,
                    text: args.text,
                    letterSpacing: args.letterSpacing
                )

                canvas.send()

                // Sleep without blocking
                try? await Task.sleep(for: .milliseconds(args.scrollDelayMs))
            }

            if !args.runOnce {
                continue_loop = !shouldStop
            } else {
                continue_loop = false
            }
        }
    }

    private func displayVerticalScroll(yPos: Int, xPos: Int) async {
        let height = canvas.height
        let textHeight = measureTextHeight(args.text)

        var continue_loop = true
        while continue_loop && !shouldStop {
            for s in 0...(textHeight + height) {
                if shouldStop {
                    continue_loop = false
                    break
                }

                let scrollPos = height + font.fontHeight() - s

                canvas.fill(color: args.backgroundColor)

                if let outline = args.outlineColor {
                    _ = drawVerticalText(
                        canvas: canvas,
                        font: font,
                        x: xPos - 1,
                        y: scrollPos,
                        color: outline,
                        backgroundColor: nil,
                        text: args.text,
                        letterSpacing: args.letterSpacing - 2
                    )
                }

                _ = drawVerticalText(
                    canvas: canvas,
                    font: font,
                    x: xPos,
                    y: scrollPos,
                    color: args.textColor,
                    backgroundColor: nil,
                    text: args.text,
                    letterSpacing: args.letterSpacing
                )

                canvas.send()

                // Sleep without blocking
                try? await Task.sleep(for: .milliseconds(args.scrollDelayMs))
            }

            if !args.runOnce {
                continue_loop = !shouldStop
            } else {
                continue_loop = false
            }
        }
    }

    private nonisolated func displayStatic(yPos: Int, xPos: Int) {
        canvas.fill(color: args.backgroundColor)

        if let outline = args.outlineColor {
            if args.verticalMode {
                _ = drawVerticalText(
                    canvas: canvas,
                    font: font,
                    x: xPos - 1,
                    y: font.fontHeight() - 1,
                    color: outline,
                    backgroundColor: nil,
                    text: args.text,
                    letterSpacing: args.letterSpacing - 2
                )
            } else {
                _ = drawText(
                    canvas: canvas,
                    font: font,
                    x: 0,
                    y: yPos,
                    color: outline,
                    backgroundColor: nil,
                    text: args.text,
                    letterSpacing: args.letterSpacing - 2
                )
            }
        }

        if args.verticalMode {
            _ = drawVerticalText(
                canvas: canvas,
                font: font,
                x: xPos,
                y: font.fontHeight() - 1,
                color: args.textColor,
                backgroundColor: nil,
                text: args.text,
                letterSpacing: args.letterSpacing
            )
        } else {
            _ = drawText(
                canvas: canvas,
                font: font,
                x: 1,
                y: yPos,
                color: args.textColor,
                backgroundColor: nil,
                text: args.text,
                letterSpacing: args.letterSpacing
            )
        }

        canvas.send()
    }

    private nonisolated func measureTextWidth(_ text: String) -> Int {
        var width = 0
        for scalar in text.unicodeScalars {
            width += font.characterWidth(scalar.value)
            width += args.letterSpacing
        }
        return width
    }

    private nonisolated func measureTextHeight(_ text: String) -> Int {
        let charCount = text.count
        return charCount * (font.fontHeight() + args.letterSpacing)
    }
}
