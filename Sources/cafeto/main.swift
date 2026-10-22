import Foundation
import CafetoCore
import Dispatch


func printUsage() {
    print("""
    Cafeto - mini lenguaje con tema cafetero

    Uso:
      cafeto [opciones] <archivo.txt>

    Opciones:
      -q, --no-tokens   No imprime la lista de tokens
      -h, --help        Muestra esta ayuda
    """)
}

func readSource(_ path: String) -> String? {
    for encoding in [String.Encoding.utf8, .utf16] {
        if var text = try? String(contentsOfFile: path, encoding: encoding) {
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }   // quita el BOM
            return text
        }
    }
    return nil
}

var showTokens = true
var inputPath: String? = nil
for argument in CommandLine.arguments.dropFirst() {
    switch argument {
    case "-q", "--no-tokens": showTokens = false
    case "-h", "--help":
        printUsage()
        exit(0)
    default: inputPath = argument
    }
}

guard let path = inputPath else {
    printUsage()
    exit(64)
}

guard let source = readSource(path) else {
    FileHandle.standardError.write(Data("Error: cannot read file '\(path)'\n".utf8))
    exit(66)
}

// Se ejecuta en un hilo con pila grande para soportar recursión profunda.
final class ResultBox { var ok = false }
let box = ResultBox()
let tokensFlag = showTokens
let done = DispatchSemaphore(value: 0)
let worker = Thread {
    box.ok = CafetoEngine(showTokens: tokensFlag).run(source: source)
    done.signal()
}
worker.stackSize = 256 * 1024 * 1024
worker.start()
done.wait()
exit(box.ok ? 0 : 1)