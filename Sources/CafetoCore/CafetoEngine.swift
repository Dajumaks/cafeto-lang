import Foundation

/// Punto de entrada público: coordina lexer, parser e intérprete.
public final class CafetoEngine {
    private let showTokens: Bool
    private let output: (String) -> Void
    private let errorOutput: (String) -> Void
    private let input: () -> String?

    public init(
        showTokens: Bool = true,
        output: @escaping (String) -> Void = { print($0, terminator: "") },
        errorOutput: @escaping (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) },
        input: @escaping () -> String? = { readLine() }
    ) {
        self.showTokens = showTokens
        self.output = output
        self.errorOutput = errorOutput
        self.input = input
    }

    /// Ejecuta un programa. Devuelve `true` si terminó sin errores.
    @discardableResult
    public func run(source: String) -> Bool {
        // 1. Análisis léxico
        var lexer = Lexer(source: source)
        let tokens = lexer.tokenize()
        if showTokens {
            output("== TOKENS ==\n")
            for token in tokens where token.type != .eof {
                output(token.description + "\n")
            }
        }
        if !lexer.errors.isEmpty {
            for error in lexer.errors { errorOutput(error.description) }
            return false
        }

        // 2. Análisis sintáctico
        var parser = Parser(tokens: tokens)
        let program: [Stmt]
        do {
            program = try parser.parseProgram()
        } catch let diagnostic as Diagnostic {
            errorOutput(diagnostic.description)
            return false
        } catch {
            errorOutput("Unexpected error: \(error)")
            return false
        }

        // 3. Ejecución
        if showTokens { output("== OUTPUT ==\n") }
        let interpreter = Interpreter(output: output, input: input)
        do {
            try interpreter.run(program)
        } catch let diagnostic as Diagnostic {
            errorOutput(diagnostic.description)
            return false
        } catch let thrown as ThrownValue {
            errorOutput("Runtime error on line \(thrown.line): uncaught exception: \(thrown.value.display)")
            return false
        } catch {
            errorOutput("Unexpected error: \(error)")
            return false
        }
        return true
    }
}