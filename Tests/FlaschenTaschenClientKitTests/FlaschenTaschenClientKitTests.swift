import Testing
import FlaschenTaschenClientKit

@Suite
struct FlaschenTaschenClientKitTests {
    @Test
    func testColorCreation() {
        let color = Color(r: 255, g: 128, b: 64)
        #expect(color.r == 255)
        #expect(color.g == 128)
        #expect(color.b == 64)
    }

    @Test
    func argumentPreprocessor() {
        let args = ["-hlocalhost", "-g45x35", "-l10", "-O"]
        let expected = ["-h", "localhost", "-g", "45x35", "-l", "10", "-O"]

        let processed = ArgumentPreprocessor.preprocess(args: args)

        #expect(expected == processed)

    }
}
