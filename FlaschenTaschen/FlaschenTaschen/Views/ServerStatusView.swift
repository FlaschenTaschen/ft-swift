// ServerStatusView.swift

import SwiftUI

struct ServerStatusView: View {
    @Bindable var displayModel: DisplayModel

    var body: some View {

        // Metrics
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                Text("Packets:")
                    .font(.system(.caption2))
                Text("\(displayModel.packetsReceived)")
                    .font(.system(.caption, design: .monospaced))
            }

            HStack(spacing: 3) {
                Text("FPS:")
                    .font(.system(.caption2))
                Text("\(displayModel.currentFPS)")
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Text("Target:")
                    .font(.system(.caption2))
                Text("\(displayModel.maxFrameRate) FPS")
                    .monospacedDigit()
                    .font(.system(.caption, design: .monospaced))
                    .padding(.trailing, 10.0)
            }

            HStack {
                Text("Layers:")
                    .font(.system(.caption2))
                Text("\(displayModel.activeLayers.count)")
                    .monospacedDigit()
                    .font(.system(.caption, design: .monospaced))
                    .padding(.trailing, 10.0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 10) {
                    if !displayModel.activeLayers.isEmpty {
                        ForEach(displayModel.activeLayers, id: \.self) { layer in
                            if let stats = displayModel.layerStats[layer] {
                                CompactLayerDetailView(stats: stats, layerTimeout: displayModel.layerTimeout)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CompactLayerDetailView: View {
    let stats: LayerStatistics
    let layerTimeout: Int

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack {
                Text("\(stats.layerID)")
                    .font(.system(.caption, weight: .semibold))
                Text("\(stats.pixelsActive)px")
                    .font(.system(.caption, design: .monospaced))
            }

            let percentClosed = min(100, (stats.timeSinceUpdate / Double(layerTimeout)) * 100)
            ClosingCircleView(percentClosed: percentClosed, size: 10.0)
        }
        .cornerRadius(3)
    }
}

