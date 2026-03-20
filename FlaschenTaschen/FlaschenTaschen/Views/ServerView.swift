// ServerView.swift

import SwiftUI
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ServerView")

struct ServerView: View {
    @Bindable var displayModel: DisplayModel
    @Binding var showServerView: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ServerControlsView(displayModel: displayModel)

            Divider()
                .frame(height: 16)

            Spacer()

            ServerStatusView(displayModel: displayModel)

            Spacer()

            Divider()
                .frame(height: 16)

            // Collapse button
            Button(action: {
                logger.info("Collapse tapped, setting showServerView=false")
                showServerView = false
            }) {
                Text("▼")
                    .font(.system(.caption, weight: .semibold))
            }
            .help("Collapse")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .controlBackground()
        .cornerRadius(6)
        .padding(8)
    }
}

#Preview {
    let model = DisplayModel()
    ServerView(displayModel: model, showServerView: .constant(false))
}
