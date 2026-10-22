/// Analizador léxico escrito a mano. Acepta saltos de línea LF y CRLF.
struct Lexer {
    private let chars: [Character]
    private var pos = 0
    private var line = 1
    private(set) var errors: [Diagnostic] = []

    init(source: String) {
        chars = Array(source)
    }

    mutating func tokenize() -> [Token] {
        var tokens: [Token] = []
        while pos < chars.count {
            let c = chars[pos]
            if isNewline(c) { line += 1; pos += 1; continue }
            if c == " " || c == "\t" || c == "\r" { pos += 1; continue }
            if c == "#" {                       // comentario de una línea
                while pos < chars.count && !isNewline(chars[pos]) { pos += 1 }
                continue
            }
            if isLetter(c) { tokens.append(identifier()); continue }
            if isDigit(c) { tokens.append(number()); continue }
            if c == "\"" {
                if let token = string() { tokens.append(token) }
                continue
            }
            if let type = symbol(for: c) {
                tokens.append(Token(type, String(c), line))
                pos += 1
                continue
            }
            errors.append(Diagnostic(.lexical, line, "unrecognized symbol '\(c)'"))
            pos += 1
        }
        tokens.append(Token(.eof, "", tokens.last?.line ?? line))
        return tokens
    }

    // MARK: - Helpers

    private func isNewline(_ c: Character) -> Bool { c == "\n" || c == "\r\n" }
    private func isLetter(_ c: Character) -> Bool { c == "_" || (c.isASCII && c.isLetter) }
    private func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

    private func symbol(for c: Character) -> TokenType? {
        switch c {
        case "+": return .plus
        case "-": return .minus
        case "*": return .star
        case "/": return .slash
        case "%": return .percent
        case "(": return .lparen
        case ")": return .rparen
        case "[": return .lbracket
        case "]": return .rbracket
        case ",": return .comma
        case ".": return .dot
        case ":": return .colon
        default: return nil
        }
    }

    private mutating func identifier() -> Token {
        let start = pos
        while pos < chars.count && (isLetter(chars[pos]) || isDigit(chars[pos])) { pos += 1 }
        let text = String(chars[start..<pos])
        return Token(keywordTable[text] ?? .id, text, line)
    }

    private mutating func number() -> Token {
        let start = pos
        while pos < chars.count && isDigit(chars[pos]) { pos += 1 }
        var type = TokenType.intNumber
        if pos + 1 < chars.count, chars[pos] == ".", isDigit(chars[pos + 1]) {
            type = .realNumber
            pos += 1
            while pos < chars.count && isDigit(chars[pos]) { pos += 1 }
        }
        return Token(type, String(chars[start..<pos]), line)
    }

    private mutating func string() -> Token? {
        let startLine = line
        pos += 1                                  // comilla de apertura
        var value = ""
        while pos < chars.count {
            let c = chars[pos]
            if c == "\"" {
                pos += 1
                return Token(.string, value, startLine)
            }
            if isNewline(c) { break }
            if c == "\\" {
                pos += 1
                guard pos < chars.count else { break }
                switch chars[pos] {
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                default:
                    errors.append(Diagnostic(.lexical, line, "invalid escape sequence '\\\(chars[pos])'"))
                }
                pos += 1
                continue
            }
            value.append(c)
            pos += 1
        }
        errors.append(Diagnostic(.lexical, startLine, "unterminated string"))
        return nil
    }
}