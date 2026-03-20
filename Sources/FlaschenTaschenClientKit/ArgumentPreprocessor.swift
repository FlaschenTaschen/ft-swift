// FlaschenTaschenClientKit - Swift library for Flaschen Taschen UDP communication

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "BDFFont")

public enum ArgumentPreprocessor {
    public static func preprocess(args: [String]) -> [String] {
        let processed: [String] = args.reduce(into: []) { output, arg in
            if arg.hasPrefix("-") && arg.count > 2 {
                let flag = String(arg.prefix(2))
                let remainder = String(arg.dropFirst(2))
                output.append(flag)
                output.append(remainder)
            } else {
                output.append(arg)
            }
        }

        return processed
    }
}
