// ControlBackgroundViewModifier.swift

import SwiftUI
import os.log
#if os(macOS)
import AppKit
#endif

nonisolated private let logger = Logger(subsystem: "ChatGPT", category: "ControlBackgroundViewModifier")

struct ControlBackgroundViewModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .background(Color(.controlBackgroundColor).opacity(0.9))
            #else
            .background(.gray.opacity(0.2))
            #endif
    }
}

extension View {
    func controlBackground() -> some View {
        modifier(ControlBackgroundViewModifier())
    }
}
