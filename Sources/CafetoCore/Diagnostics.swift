/// Error léxico, sintáctico o de ejecución, siempre con su línea.
struct Diagnostic: Error, CustomStringConvertible {
    enum Kind { case lexical, syntax, runtime }

    let kind: Kind
    let line: Int
    let message: String

    init(_ kind: Kind, _ line: Int, _ message: String) {
        self.kind = kind
        self.line = line
        self.message = message
    }

    var description: String {
        switch kind {
        case .lexical: return "Lexical error on line \(line): \(message)"
        case .syntax: return "Syntax error on line \(line): \(message)"
        case .runtime: return "Runtime error on line \(line): \(message)"
        }
    }
}

/// Excepción lanzada por el usuario con `volcar`.
struct ThrownValue: Error, @unchecked Sendable {
    let value: Value
    let line: Int
}