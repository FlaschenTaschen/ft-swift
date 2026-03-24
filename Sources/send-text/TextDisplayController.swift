// Text display controller - handles scrolling and rendering modes

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendText")

actor TextDisplayController {
    private let canvas: UDPFlaschenTaschen
    private let font: BDFFont
    private let args: TextArgs

    init(canvas: UDPFlaschenTaschen, font: BDFFont, args: TextArgs) {
        self.canvas = canvas
        self.font = font
        self.args = args
    }

    func displayText() async {
        let width = canvas.width
        let height = canvas.height

        // Determine actual display height
        let displayHeight = args.standardOptions.height > 0 ? args.standardOptions.height : height

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
            await displayStaticWithTimeout(yPos: yPos, xPos: xPos)
        }

        // Clear display if not scrolling forever
        if args.standardOptions.layer > 0 && args.scrollDelayMs > 0 {
            canvas.clear()
            canvas.send()
        }
    }

    private func displayHorizontalScroll(yPos: Int) async {
        let width = canvas.width
        let textWidth = measureTextWidth(args.text)
        let scrollRange = textWidth + width
        let loop = AnimationLoop(timeout: args.standardOptions.timeout, delay: args.scrollDelayMs)
        let runOnce = args.runOnce
        let backgroundColor = args.backgroundColor
        let textColor = args.textColor
        let outlineColor = args.outlineColor
        let letterSpacing = args.letterSpacing
        let text = args.text

        while loop.shouldContinue() {
            let frameCount = loop.frameCount
            let s = runOnce ? frameCount % (scrollRange + 1) : frameCount % (scrollRange + 1)
            let scrollPos = width - s

            canvas.fill(color: backgroundColor)

            if let outline = outlineColor {
                _ = drawText(
                    canvas: canvas,
                    font: font,
                    x: scrollPos,
                    y: yPos,
                    color: outline,
                    backgroundColor: nil,
                    text: text,
                    letterSpacing: letterSpacing - 2
                )
            }

            _ = drawText(
                canvas: canvas,
                font: font,
                x: scrollPos + 1,
                y: yPos,
                color: textColor,
                backgroundColor: nil,
                text: text,
                letterSpacing: letterSpacing
            )

            canvas.send()
            loop.nextFrame()

            do {
                try await loop.sleep()
            } catch {
                break
            }
        }
    }

    private func displayVerticalScroll(yPos: Int, xPos: Int) async {
        let height = canvas.height
        let textHeight = measureTextHeight(args.text)
        let scrollRange = textHeight + height
        let loop = AnimationLoop(timeout: args.standardOptions.timeout, delay: args.scrollDelayMs)
        let runOnce = args.runOnce
        let backgroundColor = args.backgroundColor
        let textColor = args.textColor
        let outlineColor = args.outlineColor
        let letterSpacing = args.letterSpacing
        let text = args.text
        let fontHeight = font.fontHeight()

        while loop.shouldContinue() {
            let frameCount = loop.frameCount
            let s = runOnce ? frameCount % (scrollRange + 1) : frameCount % (scrollRange + 1)
            let scrollPos = height + fontHeight - s

            canvas.fill(color: backgroundColor)

            if let outline = outlineColor {
                _ = drawVerticalText(
                    canvas: canvas,
                    font: font,
                    x: xPos - 1,
                    y: scrollPos,
                    color: outline,
                    backgroundColor: nil,
                    text: text,
                    letterSpacing: letterSpacing - 2
                )
            }

            _ = drawVerticalText(
                canvas: canvas,
                font: font,
                x: xPos,
                y: scrollPos,
                color: textColor,
                backgroundColor: nil,
                text: text,
                letterSpacing: letterSpacing
            )

            canvas.send()
            loop.nextFrame()

            do {
                try await loop.sleep()
            } catch {
                break
            }
        }
    }

    private func displayStaticWithTimeout(yPos: Int, xPos: Int) async {
        let loop = AnimationLoop(timeout: args.standardOptions.timeout, delay: 100)

        while loop.shouldContinue() {
            displayStatic(yPos: yPos, xPos: xPos)
            loop.nextFrame()

            do {
                try await loop.sleep()
            } catch {
                break
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
