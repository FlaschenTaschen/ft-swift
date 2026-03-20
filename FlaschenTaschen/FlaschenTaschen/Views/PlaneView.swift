// PlaneView.swift

import SwiftUI
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "PlaneView")

struct PlaneView: View {
    @Bindable var displayModel: DisplayModel
    @State private var showTVOSControls: Bool = false

    var body: some View {
        #if os(tvOS)
        ZStack(alignment: .bottom) {
            PixelGridView(displayModel: displayModel)

            if showTVOSControls {
                TVOSControlsView(displayModel: displayModel, isShowing: $showTVOSControls)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .focusable()
        .onMoveCommand { direction in
            if direction == .up {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTVOSControls = true
                }
            } else if direction == .down {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTVOSControls = false
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { geo in
            geo.size
        } action: { size in
            let dimensions = displayModel.calculateOptimalTVOSGridDimensions(for: size)
            displayModel.updateGridDimensions(width: dimensions.width, height: dimensions.height)
        }
        #else
        ZStack(alignment: .bottomTrailing) {
            PixelGridView(displayModel: displayModel)

            #if os(macOS)
            ServerPanelView(displayModel: displayModel)
            #endif
        }
        #endif
    }
}

#Preview {
    let model = DisplayModel()
    PlaneView(displayModel: model)
}
