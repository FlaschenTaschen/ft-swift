// FlaschenTaschenApp.swift

import SwiftUI

#if os(tvOS)
import UIKit
#endif

import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "App")

@main
struct FlaschenTaschenApp: App {
    @State private var displayModel = DisplayModel()

    #if os(tvOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(displayModel: displayModel)
                #if os(tvOS)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                #endif
        }

        #if os(macOS)
        Settings {
            SettingsView(displayModel: displayModel)
        }
        #endif
    }
}

#if os(tvOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationDidEnterBackground(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.shared.isIdleTimerDisabled = true
    }
}
#endif
