import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "FlaschenTaschenDetector")

@main
struct FlaschenTaschenDetector {
    enum OutputFormat: Sendable {
        case human
        case shell
        case json
    }

    struct Options: Sendable {
        var listDisplays: Bool = false
        var queryName: String?
        var outputFormat: OutputFormat = .human
        var timeoutSeconds: TimeInterval = 5.0
        var verbose: Bool = false
        var clientTool: String?
        var clientArgs: [String] = []
    }

    static func main() async {
        let options = parseArguments(CommandLine.arguments)

        if options.verbose && options.clientTool == nil {
            logger.info("Discovering FlaschenTaschen displays (timeout: \(Int(options.timeoutSeconds * 1000))ms)...")
        }

        let displays = await discoverDisplays(timeoutSeconds: options.timeoutSeconds)

        // List mode
        if options.listDisplays {
            if displays.isEmpty {
                print("No FlaschenTaschen displays found.")
            } else {
                for display in displays {
                    printDisplayHuman(display)
                    if display != displays.last {
                        print("")
                    }
                }
            }
            return
        }

        // Query mode
        if let queryName = options.queryName {
            if let display = displays.first(where: { service in
                service.instanceName.lowercased().contains(queryName.lowercased()) ||
                service.name.lowercased().contains(queryName.lowercased())
            }) {
                switch options.outputFormat {
                case .human:
                    printDisplayHuman(display)
                case .shell:
                    printDisplayShell(display)
                case .json:
                    printDisplayJSON(display)
                }

                // If there's a client tool to invoke
                if let tool = options.clientTool {
                    if options.verbose {
                        let geometry = "\(display.width)x\(display.height)"
                        logger.info("Discovered: \(display.name) (\(display.address):\(display.port), \(geometry))")
                        logger.info("Executing: \(tool) -h \(display.address) -g \(geometry) \(options.clientArgs.joined(separator: " "))")
                    }
                    invokeClientTool(tool: tool, toolArgs: options.clientArgs, display: display)
                }
            } else {
                print("Display matching '\(queryName)' not found.")
                exit(1)
            }
            return
        }

        // Proxy mode (invoke with first display)
        if let tool = options.clientTool {
            if let display = displays.first {
                if options.verbose {
                    let geometry = "\(display.width)x\(display.height)"
                    logger.info("Discovered: \(display.name) (\(display.address):\(display.port), \(geometry))")
                    logger.info("Executing: \(tool) -h \(display.address) -g \(geometry) \(options.clientArgs.joined(separator: " "))")
                }
                invokeClientTool(tool: tool, toolArgs: options.clientArgs, display: display)
            } else {
                print("No FlaschenTaschen displays found.")
                exit(1)
            }
            return
        }

        // Default: list all displays
        if displays.isEmpty {
            print("No FlaschenTaschen displays found.")
        } else {
            for display in displays {
                printDisplayHuman(display)
                if display != displays.last {
                    print("")
                }
            }
        }
    }

    // MARK: - Output Formatting

    private static func printDisplayHuman(_ service: DisplayService) {
        print(service.instanceName)
        print("  Address: \(service.address)")
        print("  Hostname: \(service.hostname)")
        print("  Port: \(service.port)")
        print("  Geometry: \(service.width)x\(service.height)")
        if let url = service.url {
            print("  URL: \(url)")
        }
    }

    private static func printDisplayShell(_ display: DisplayService) {
        print("FT_NAME=\"\(display.name)\"")
        print("FT_HOST=\"\(display.address)\"")
        print("FT_PORT=\"\(display.port)\"")
        print("FT_WIDTH=\"\(display.width)\"")
        print("FT_HEIGHT=\"\(display.height)\"")
        if let url = display.url {
            print("FT_URL=\"\(url)\"")
        }
    }

    private static func printDisplayJSON(_ display: DisplayService) {
        let dict: [String: Any] = [
            "name": display.name,
            "instanceName": display.instanceName,
            "hostname": display.hostname,
            "address": display.address,
            "port": display.port,
            "width": display.width,
            "height": display.height,
            "url": display.url as Any
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    // MARK: - Tool Invocation

    private static func invokeClientTool(
        tool: String,
        toolArgs: [String],
        display: DisplayService
    ) {
        let geometry = "\(display.width)x\(display.height)"
        let argv = [tool, "-h", display.address, "-g", geometry] + toolArgs
        let cArgs = argv.map { strdup($0) } + [nil as UnsafeMutablePointer<CChar>?]

        defer {
            for ptr in cArgs {
                guard let ptr = ptr else { continue }
                free(ptr)
            }
        }

        var mutableArgs = cArgs
        execvp(cArgs[0]!, &mutableArgs)

        // Only reached on error
        perror("execvp")
        exit(1)
    }

    // MARK: - Argument Parsing

    private static func parseArguments(_ args: [String]) -> Options {
        var options = Options()
        var i = 1

        while i < args.count {
            let arg = args[i]

            switch arg {
            case "-l", "--list":
                options.listDisplays = true
                i += 1

            case "-q", "--query":
                if i + 1 < args.count {
                    options.queryName = args[i + 1]
                    i += 2
                } else {
                    i += 1
                }

            case "-f", "--format":
                if i + 1 < args.count {
                    let format = args[i + 1].lowercased()
                    options.outputFormat = format == "json" ? .json : .shell
                    i += 2
                } else {
                    i += 1
                }

            case "-t", "--timeout":
                if i + 1 < args.count, let timeout = TimeInterval(args[i + 1]) {
                    options.timeoutSeconds = timeout / 1000.0  // Convert from milliseconds
                    i += 2
                } else {
                    i += 1
                }

            case "-v", "--verbose":
                options.verbose = true
                i += 1

            case "-h", "--help":
                printUsage()
                exit(0)

            default:
                // First non-option arg is the client tool
                if !arg.hasPrefix("-") {
                    options.clientTool = arg
                    i += 1
                    // Remaining args are client args
                    options.clientArgs = Array(args[i...])
                    break
                }
                i += 1
            }
        }

        return options
    }

    private static func printUsage() {
        print("""
            Usage: ft-detect [options] [client-tool] [client-args...]

            Options:
              -l, --list              List all discovered displays and exit
              -q, --query <name>      Query for specific display name (case-insensitive partial match)
              -f, --format <sh|json>  Output format for query results (sh: shell vars, json: JSON)
              -t, --timeout <ms>      Discovery timeout in milliseconds (default: 5000)
              -v, --verbose           Verbose output
              -h, --help              Show this help

            Examples:
              ft-detect                          # List displays
              ft-detect -q "Polaris"             # Query for "Polaris" display
              ft-detect -q "Polaris" -f sh       # Query, output as shell variables
              ft-detect send-image photo.jpg     # Discover first display, run send-image
              ft-detect -q "Polaris" send-image photo.jpg  # Discover "Polaris", run send-image
            """)
    }
}
