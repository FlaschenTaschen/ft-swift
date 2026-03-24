// ServerControlsView.swift

import SwiftUI

public struct ServerControlsView: View {
    @Bindable var displayModel: DisplayModel

    public var body: some View {
        // Status: green dot + Running/Stopped
        HStack(spacing: 6) {
            Circle()
                .fill(displayModel.isServerRunning ? .green : .red)
                .frame(width: 6, height: 6)
            Text(displayModel.isServerRunning ? "Running" : "Stopped")
                .font(.system(.caption, weight: .semibold))
        }

        // Control buttons
        HStack(spacing: 6) {
            Button(action: {
                if displayModel.isServerRunning {
                    displayModel.stopServer()
                } else {
                    Task {
                        await displayModel.startServer()
                    }
                }
            }) {
                Text(displayModel.isServerRunning ? "Stop" : "Start")
                    .font(.system(.caption, weight: .semibold))
            }
            .controlSize(.small)
            .buttonStyle(.bordered)

            Button(action: {
                displayModel.resetDisplay()
            }) {
                Text("Clear")
                    .font(.system(.caption, weight: .semibold))
            }
            .controlSize(.small)
            .buttonStyle(.bordered)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(.caption))
                    Toggle("", isOn: $displayModel.useCirclePixels)
                        .onChange(of: displayModel.useCirclePixels) {
                            displayModel.saveSettings()
                        }
                        .labelsHidden()
                }

                HStack(spacing: 6) {
                    Image(systemName: "circle")
                        .font(.system(.caption))
                    Toggle("", isOn: $displayModel.useLensDistortion)
                        .onChange(of: displayModel.useLensDistortion) {
                            displayModel.saveSettings()
                        }
                        .labelsHidden()
                }
            }

        }
    }
}
