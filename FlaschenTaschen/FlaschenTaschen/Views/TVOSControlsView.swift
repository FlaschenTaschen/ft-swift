// TVOSControlsView.swift

#if os(tvOS)
import SwiftUI

struct TVOSControlsView: View {
    @Bindable var displayModel: DisplayModel
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Label("IP:", systemImage: "network")
                            .font(.system(.caption, design: .monospaced))
                        Text(displayModel.ipAddress)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Label("Grid:", systemImage: "square.grid.2x2")
                            .font(.system(.caption, design: .monospaced))
                        Text("\(displayModel.gridWidth)×\(displayModel.gridHeight)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: { isShowing = false }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .controlBackground()
        .cornerRadius(8)
        .padding(12)
    }
}

#Preview {
    let model = DisplayModel()
    TVOSControlsView(displayModel: model, isShowing: .constant(true))
}
#endif
