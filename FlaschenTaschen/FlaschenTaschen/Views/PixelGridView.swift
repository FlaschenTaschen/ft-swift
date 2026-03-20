// PixelGridView.swift

import SwiftUI
import os.log
import CoreImage

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "PixelGridView")

struct PixelGridView: View {
    @Bindable var displayModel: DisplayModel
    @State private var pixelSize: CGFloat = 16
    @State private var isFullScreen: Bool = false
    @State private var showServerPanel: Bool = true

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(pixelSize), spacing: 0), count: displayModel.gridWidth)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.black)
                .ignoresSafeArea()

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(displayModel.pixelData, id: \.id) { pixelColor in
                        PixelView(pixelColor: pixelColor, size: pixelSize, useCircle: displayModel.useCirclePixels, useLensDistortion: displayModel.useLensDistortion)
                    }
                }
                .padding(8)
            }
            .onGeometryChange(for: CGSize.self) { geo in
                geo.size
            } action: { size in
                let availableWidth = size.width - 16
                let availableHeight = size.height - 16
                pixelSize = min(
                    availableWidth / CGFloat(displayModel.gridWidth),
                    availableHeight / CGFloat(displayModel.gridHeight)
                )
            }
        }
        .overlay {
            if let error = displayModel.serverError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .controlBackground()
                .cornerRadius(8)
            }
        }
    }
}

struct PixelView: View {
    let pixelColor: PixelColor
    let size: CGFloat
    let useCircle: Bool
    let useLensDistortion: Bool

    var body: some View {
        if useCircle {
            if useLensDistortion {
                LensDistortedCircleView(color: pixelColor.color, size: size)
            } else {
                Circle()
                    .fill(pixelColor.color)
                    .frame(width: size, height: size)
            }
        } else {
            Rectangle()
                .fill(pixelColor.color)
                .frame(width: size, height: size)
                .border(.gray.opacity(0.3), width: 0.5)
        }
    }
}

struct LensDistortedCircleView: View {
    let color: Color
    let size: CGFloat
    @State private var distortedImage: Image?

    var body: some View {
        ZStack {
            if let distortedImage {
                distortedImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .onAppear {
                        generateDistortedImage()
                    }
            }

            // Radial gradient overlay for glossy glass effect
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(0.6), location: 0.0),
                    .init(color: Color.white.opacity(0.2), location: 0.4),
                    .init(color: Color.white.opacity(0.0), location: 0.8)
                ]),
                center: UnitPoint(x: 0.35, y: 0.35),
                startRadius: 0,
                endRadius: size / 2
            )
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .onChange(of: color) {
            generateDistortedImage()
        }
    }

    private func generateDistortedImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let cgImage = createCircleCGImage(color: color, size: size) {
                let ciImage = CIImage(cgImage: cgImage)
                if let distorted = applyLensDistortion(ciImage) {
                    let context = CIContext()
                    if let outputCG = context.createCGImage(distorted, from: distorted.extent) {
                        DispatchQueue.main.async {
                            self.distortedImage = Image(outputCG, scale: 1.0, label: Text(""))
                        }
                    }
                }
            }
        }
    }

    private func createCircleCGImage(color: Color, size: CGFloat) -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: Int(size) * 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }

        #if os(macOS)
        let platformColor = NSColor(color)
        #else
        let platformColor = UIColor(color)
        #endif

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1.0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        context.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
        context.fillEllipse(in: rect)

        return context.makeImage()
    }

    private func applyLensDistortion(_ ciImage: CIImage) -> CIImage? {
        let filter = CIFilter(name: "CILensDistortion")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)

        // Radius defines the size of the effect area
        filter?.setValue(size / 2, forKey: "inputRadius")

        // Intensity controls how strong the lens effect is (0.0 to 1.0+)
        // Positive values create convex lens (bulging) effect like beer bottle bottom
        filter?.setValue(0.8, forKey: "inputIntensity")

        return filter?.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    let model = DisplayModel()
    PixelGridView(displayModel: model)
}
