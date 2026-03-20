// midi - Player piano visualization driven by MIDI input
// Ported from midi.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit

@main
struct Midi {
    static func main() {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        // TODO: Read MIDI input and render notes
    }

    static func printUsage() {
        print("midi: Player piano visualization from MIDI input")
        print("Usage: cat /dev/midi | midi [options] {scroll|across|boxes}")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -c <RRGGBB>    : Note color")
    }
}
