// SettingsView.swift

import SwiftUI

struct DisplayPreset {
    let name: String
    let width: Int
    let height: Int
    let pixelSize: CGFloat

    static let presets: [DisplayPreset] = [
        DisplayPreset(name: "Original", width: 45, height: 35, pixelSize: 16),
        DisplayPreset(name: "Small", width: 32, height: 24, pixelSize: 8),
        DisplayPreset(name: "Medium", width: 45, height: 35, pixelSize: 8),
        DisplayPreset(name: "Large", width: 64, height: 48, pixelSize: 8),
        DisplayPreset(name: "Very Large", width: 128, height: 96, pixelSize: 4),
    ]
}

#if os(macOS)
struct SettingsView: View {
    @Bindable var displayModel: DisplayModel
    @State private var tempGridWidth: String = ""
    @State private var tempGridHeight: String = ""
    @State private var selectedPresetName: String = "Custom"
    @State private var selectedFrameRate: Int = 60
    @State private var tempLayerTimeout: String = ""

    var body: some View {
        Form {
            Section("Preset") {
                Picker("Display Configuration", selection: $selectedPresetName) {
                    ForEach(DisplayPreset.presets, id: \.name) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                    Text("Custom").tag("Custom")
                }
                .onChange(of: selectedPresetName) { _, newValue in
                    if let preset = DisplayPreset.presets.first(where: { $0.name == newValue }) {
                        tempGridWidth = String(preset.width)
                        tempGridHeight = String(preset.height)
                    }
                }
            }

            Section("Display Grid") {
                HStack {
                    Text("Width")
                    Spacer()
                    TextField("", text: $tempGridWidth)
                        .frame(width: 80)
                        .disabled(selectedPresetName != "Custom")
                }

                HStack {
                    Text("Height")
                    Spacer()
                    TextField("", text: $tempGridHeight)
                        .frame(width: 80)
                        .disabled(selectedPresetName != "Custom")
                }
            }

            Section("Performance") {
                Picker("Target Frame Rate", selection: $selectedFrameRate) {
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                    Text("120 FPS").tag(120)
                }
            }

            Section("Network") {
                HStack {
                    Text("Listen Port")
                    Spacer()
                    Text("1337")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Bind Address")
                    Spacer()
                    Text("0.0.0.0")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Layers") {
                HStack {
                    Text("Layer Timeout (seconds)")
                    Spacer()
                    TextField("", text: $tempLayerTimeout)
                        .frame(width: 60)
                }
            }

            Section {
                Button(action: applySettings) {
                    Text("Apply Changes")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadCurrentSettings()
        }
    }

    private var hasChanges: Bool {
        guard let currentWidth = Int(tempGridWidth),
              let currentHeight = Int(tempGridHeight),
              let currentLayerTimeout = Int(tempLayerTimeout) else {
            return false
        }
        return currentWidth != displayModel.gridWidth ||
               currentHeight != displayModel.gridHeight ||
               selectedFrameRate != displayModel.maxFrameRate ||
               currentLayerTimeout != displayModel.layerTimeout
    }

    private func loadCurrentSettings() {
        tempGridWidth = String(displayModel.gridWidth)
        tempGridHeight = String(displayModel.gridHeight)
        selectedFrameRate = displayModel.maxFrameRate
        tempLayerTimeout = String(displayModel.layerTimeout)
        updatePresetSelection()
    }

    private func updatePresetSelection() {
        let currentWidth = Int(tempGridWidth) ?? 0
        let currentHeight = Int(tempGridHeight) ?? 0

        if let preset = DisplayPreset.presets.first(where: {
            $0.width == currentWidth && $0.height == currentHeight
        }) {
            selectedPresetName = preset.name
        } else {
            selectedPresetName = "Custom"
        }
    }

    private func applySettings() {
        var newWidth = displayModel.gridWidth
        var newHeight = displayModel.gridHeight
        var newLayerTimeout = displayModel.layerTimeout

        if let w = Int(tempGridWidth), w > 0, w <= 512 {
            newWidth = w
        } else {
            tempGridWidth = String(displayModel.gridWidth)
        }

        if let h = Int(tempGridHeight), h > 0, h <= 512 {
            newHeight = h
        } else {
            tempGridHeight = String(displayModel.gridHeight)
        }

        if let t = Int(tempLayerTimeout), t > 0, t <= 300 {
            newLayerTimeout = t
        } else {
            tempLayerTimeout = String(displayModel.layerTimeout)
        }

        displayModel.updateGridDimensions(width: newWidth, height: newHeight)
        displayModel.maxFrameRate = selectedFrameRate
        displayModel.layerTimeout = newLayerTimeout
        displayModel.saveSettings()
    }
}

#Preview {
    SettingsView(displayModel: DisplayModel())
}
#endif
