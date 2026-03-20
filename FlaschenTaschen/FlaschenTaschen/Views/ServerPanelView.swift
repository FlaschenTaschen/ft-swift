// ServerPanelView.swift

#if os(macOS)
import SwiftUI
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ServerPanelView")

struct ServerPanelView: View {
    @Bindable var displayModel: DisplayModel
    @State private var isFullScreen: Bool = false
    @State private var showServerView: Bool = true

    var body: some View {
        VStack(alignment: .trailing) {
            if !isFullScreen {
                if showServerView {
                    ServerView(displayModel: displayModel, showServerView: $showServerView)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    HStack {
                        Spacer()
                        Button(action: { showServerView = true }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .controlBackground()
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Show panel")
                        .padding(12)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(10)
        .padding()
        .animation(.easeInOut(duration: 0.2), value: showServerView)
        .animation(.easeInOut(duration: 0.3), value: isFullScreen)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .onChange(of: showServerView, initial: true) { _, newValue in
            logger.log("Show Server Panel: \(newValue)")
        }
    }
}

#Preview {
    let model = DisplayModel()
    ServerPanelView(displayModel: model)
}
#endif
