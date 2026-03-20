// words - Text display animation with smooth scrolling
// Ported from words.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit

@main
struct Words {
    static func main() {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        // TODO: Render scrolling text
    }

    static func printUsage() {
        print("words: Text display animation")
        print("Usage: words [options] <text>...")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -p <palette>   : 1=Nebula, 2=Fire, 3=Bluegreen")
        print("  -f <fontfile>  : Path to BDF font file")
    }
}
