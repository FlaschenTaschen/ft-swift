// kbd2midi - Keyboard to MIDI converter
// Ported from kbd2midi.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit

@main
struct Kbd2midi {
    static func main() {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        // TODO: Read keyboard input and output MIDI events
    }

    static func printUsage() {
        print("kbd2midi: Keyboard to MIDI converter")
        print("Usage: kbd2midi [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("Reads keyboard input and generates MIDI note events")
    }
}
