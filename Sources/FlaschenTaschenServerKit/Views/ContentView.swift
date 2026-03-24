// ContentView.swift

import SwiftUI
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ContentView")

public struct ContentView: View {
    public let displayModel: DisplayModel
    @Environment(\.scenePhase) var scenePhase

    public init(displayModel: DisplayModel) {
        self.displayModel = displayModel
    }

    var isRunningAsXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    public var body: some View {
        PlaneView(displayModel: displayModel)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    displayModel.stopServer()
                } else if newPhase == .active && !isRunningAsXcodePreview {
                    logger.log("Starting server due to active scene phase")
                    Task {
                        await displayModel.startServer()
                    }
                }
            }
    }
}

#Preview {
    ContentView(displayModel: DisplayModel())
}
