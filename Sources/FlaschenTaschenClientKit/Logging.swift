// Logging utilities for Flaschen Taschen clients

import Foundation
import os.log

public enum Logging {
    public static let subsystem = Bundle.main.bundleIdentifier ?? "com.flaschen-taschen.clients"
}
