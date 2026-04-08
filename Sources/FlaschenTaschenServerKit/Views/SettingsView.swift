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

enum SettingsSection: String, CaseIterable, Identifiable {
    case display = "Display"
    case performance = "Performance"
    case network = "Network"

    var id: Self { self }

    var icon: String {
        switch self {
        case .display:
            return "display"
        case .performance:
            return "gauge"
        case .network:
            return "network"
        }
    }
}

#if os(macOS)
public struct SettingsView: View {
    @Bindable var displayModel: DisplayModel
    @State private var tempGridWidth: String = ""
    @State private var tempGridHeight: String = ""
    @State private var selectedPresetName: String = "Custom"
    @State private var selectedFrameRate: Int = 60
    @State private var tempLayerTimeout: String = ""
    @State private var mdnsEnabled: Bool = false
    @State private var tempMdnsDisplayName: String = ""
    @State private var tempMdnsURL: String = ""
    @State private var selectedSection: SettingsSection = .display

    public init(displayModel: DisplayModel) {
        self._displayModel = Bindable(displayModel)
    }

    public var body: some View {
        HStack(spacing: 0) {
            List(SettingsSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .scrollDisabled(true)
            .frame(width: 180)

            VStack(alignment: .leading, spacing: 20) {
                Form {
                    switch selectedSection {
                    case .display:
                        displaySection
                    case .performance:
                        performanceSection
                    case .network:
                        networkSection
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)

                Spacer()

                HStack {
                    Spacer()
                    Button(action: applySettings) {
                        Text("Apply Changes")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 600, height: 360)
        .onAppear {
            loadCurrentSettings()
        }
    }

    @ViewBuilder
    private var displaySection: some View {
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
    }

    @ViewBuilder
    private var performanceSection: some View {
        Section("Performance") {
            Picker("Target Frame Rate", selection: $selectedFrameRate) {
                Text("30 FPS").tag(30)
                Text("60 FPS").tag(60)
                Text("120 FPS").tag(120)
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
    }

    @ViewBuilder
    private var networkSection: some View {
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

        Section("Service Discovery (mDNS)") {
            Toggle("Enable mDNS Advertisement", isOn: $mdnsEnabled)

            if mdnsEnabled {
                HStack {
                    Text("Display Name")
                    Spacer()
                    TextField("", text: $tempMdnsDisplayName)
                        .frame(width: 150)
                }

                HStack {
                    Text("URL (optional)")
                    Spacer()
                    TextField("", text: $tempMdnsURL)
                        .frame(width: 200)
                }
                .font(.system(.caption))
            }
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
               currentLayerTimeout != displayModel.layerTimeout ||
               mdnsEnabled != displayModel.mdnsEnabled ||
               tempMdnsDisplayName != displayModel.mdnsDisplayName ||
               tempMdnsURL != (displayModel.mdnsURL ?? "")
    }

    private func loadCurrentSettings() {
        tempGridWidth = String(displayModel.gridWidth)
        tempGridHeight = String(displayModel.gridHeight)
        selectedFrameRate = displayModel.maxFrameRate
        tempLayerTimeout = String(displayModel.layerTimeout)
        mdnsEnabled = displayModel.mdnsEnabled
        tempMdnsDisplayName = displayModel.mdnsDisplayName
        tempMdnsURL = displayModel.mdnsURL ?? ""
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

        // Apply mDNS settings
        displayModel.mdnsEnabled = mdnsEnabled
        displayModel.mdnsDisplayName = tempMdnsDisplayName.isEmpty ? "FlaschenTaschen" : tempMdnsDisplayName
        displayModel.mdnsURL = tempMdnsURL.isEmpty ? nil : tempMdnsURL

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
