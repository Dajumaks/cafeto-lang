/// Parser de descenso recursivo. La gramática EBNF está en docs/language-reference.md.
struct Parser {
    private let tokens: [Token]
    private var pos = 0
    private var loopDepth = 0
    private var functionDepth = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    mutating func parseProgram() throws -> [Stmt] {
        var statements: [Stmt] = []
        while !check(.eof) {
            statements.append(try statement())
        }
        return statements
    }

    // MARK: - Utilidades

    private var current: Token { tokens[pos] }

    private func check(_ type: TokenType) -> Bool { current.type == type }

    @discardableResult
    private mutating func advance() -> Token {
        let token = tokens[pos]
        if token.type != .eof { pos += 1 }
        return token
    }

    private mutating func match(_ type: TokenType) -> Bool {
        if check(type) { advance(); return true }
        return false
    }

    @discardableResult
    private mutating func expect(_ type: TokenType, _ what: String) throws -> Token {
        guard check(type) else { throw fail("expected \(what)") }
        return advance()
    }

    private func fail(_ message: String) -> Diagnostic {
        let found = current.type == .eof ? "end of file" : "'\(current.lexeme)'"
        return Diagnostic(.syntax, current.line, "\(message) (found \(found))")
    }

    private func startsExpression() -> Bool {
        switch current.type {
        case .intNumber, .realNumber, .string, .id, .lparen, .lbracket, .minus, .not,
             .kwFresco, .kwRancio, .kwVacio, .kwCafetal, .kwPlantar, .kwBarista,
             .kwMedida, .kwRaiz:
            return true
        default:
            return false
        }
    }

    private mutating func block(until terminators: Set<TokenType>, opener: Int) throws -> [Stmt] {
        var body: [Stmt] = []
        while !terminators.contains(current.type) {
            if check(.eof) {
                throw Diagnostic(.syntax, current.line,
                                 "expected 'empacar' to close the block opened on line \(opener)")
            }
            body.append(try statement())
        }
        return body
    }

    private mutating func parameters() throws -> [String] {
        try expect(.lparen, "'('")
        var params: [String] = []
        if !check(.rparen) {
            repeat {
                params.append(try expect(.id, "a parameter name").lexeme)
            } while match(.comma)
        }
        try expect(.rparen, "')'")
        return params
    }

    private mutating func arguments() throws -> [Expr] {
        try expect(.lparen, "'('")
        var args: [Expr] = []
        if !check(.rparen) {
            repeat {
                args.append(try expression())
            } while match(.comma)
        }
        try expect(.rparen, "')'")
        return args
    }

    // MARK: - Sentencias

    private mutating func statement() throws -> Stmt {
        let line = current.line
        switch current.type {
        case .kwSembrar:
            advance()
            let name = try expect(.id, "a variable name").lexeme
            var initial: Expr? = nil
            if match(.assign) { initial = try expression() }
            return .declare(name, initial, line)

        case .kwServir:
            advance()
            let args = try arguments()
            return .show(args, line)

        case .kwCatar:
            advance()
            var branches: [Branch] = []
            var elseBody: [Stmt]? = nil
            let enders: Set<TokenType> = [.kwMacchiato, .kwRistretto, .kwEmpacar]
            let firstCondition = try expression()
            try expect(.colon, "':'")
            branches.append(Branch(condition: firstCondition,
                                   body: try block(until: enders, opener: line)))
            while check(.kwMacchiato) {
                let branchLine = advance().line
                let condition = try expression()
                try expect(.colon, "':'")
                branches.append(Branch(condition: condition,
                                       body: try block(until: enders, opener: branchLine)))
            }
            if check(.kwRistretto) {
                let elseLine = advance().line
                try expect(.colon, "':'")
                elseBody = try block(until: [.kwEmpacar], opener: elseLine)
            }
            try expect(.kwEmpacar, "'empacar'")
            return .ifStmt(branches, elseBody, line)

        case .kwColar:
            advance()
            let condition = try expression()
            try expect(.colon, "':'")
            loopDepth += 1
            let body = try block(until: [.kwEmpacar], opener: line)
            loopDepth -= 1
            try expect(.kwEmpacar, "'empacar'")
            return .whileStmt(condition, body, line)

        case .kwRecolectar:
            advance()
            let name = try expect(.id, "the loop variable name").lexeme
            try expect(.kwVivero, "'vivero'")
            let from = try expression()
            try expect(.kwTaza, "'taza'")
            let to = try expression()
            try expect(.colon, "':'")
            loopDepth += 1
            let body = try block(until: [.kwEmpacar], opener: line)
            loopDepth -= 1
            try expect(.kwEmpacar, "'empacar'")
            return .forStmt(name, from, to, body, line)

        case .kwDecantar:
            if loopDepth == 0 { throw Diagnostic(.syntax, line, "'decantar' used outside of a loop") }
            advance()
            return .breakStmt(line)

        case .kwFiltrar:
            if loopDepth == 0 { throw Diagnostic(.syntax, line, "'filtrar' used outside of a loop") }
            advance()
            return .continueStmt(line)

        case .kwEntregar:
            if functionDepth == 0 { throw Diagnostic(.syntax, line, "'entregar' used outside of a function") }
            advance()
            var value: Expr? = nil
            if startsExpression() { value = try expression() }
            return .returnStmt(value, line)

        case .kwReceta:
            return .funcDecl(try functionDef())

        case .kwFinca:
            return .classDecl(try classDecl())

        case .kwPreparar:
            advance()
            try expect(.colon, "':'")
            let body = try block(until: [.kwDerrame, .kwLavar, .kwEmpacar], opener: line)
            var catchVar: String? = nil
            var catchBody: [Stmt]? = nil
            var finallyBody: [Stmt]? = nil
            if check(.kwDerrame) {
                let catchLine = advance().line
                catchVar = try expect(.id, "a name for the caught error").lexeme
                try expect(.colon, "':'")
                catchBody = try block(until: [.kwLavar, .kwEmpacar], opener: catchLine)
            }
            if check(.kwLavar) {
                let finallyLine = advance().line
                try expect(.colon, "':'")
                finallyBody = try block(until: [.kwEmpacar], opener: finallyLine)
            }
            if catchBody == nil && finallyBody == nil {
                throw Diagnostic(.syntax, line, "'preparar' needs a 'derrame' or a 'lavar' section")
            }
            try expect(.kwEmpacar, "'empacar'")
            return .tryStmt(body, catchVar, catchBody, finallyBody, line)

        case .kwVolcar:
            advance()
            return .throwStmt(try expression(), line)

        case .kwEmpacar, .kwMacchiato, .kwRistretto, .kwDerrame, .kwLavar:
            throw fail("unexpected keyword with no matching block")

        default:
            let expr = try expression()
            if match(.assign) {
                switch expr {
                case .variable, .index, .member: break
                default: throw Diagnostic(.syntax, line, "invalid assignment target")
                }
                return .assign(expr, try expression(), line)
            }
            if expr.isCallLike { return .expression(expr, line) }
            throw Diagnostic(.syntax, line, "this expression is not a valid statement")
        }
    }

    private mutating func functionDef() throws -> FuncDef {
        let line = advance().line                      // 'receta'
        let name = try expect(.id, "a function name").lexeme
        let params = try parameters()
        try expect(.colon, "':'")
        functionDepth += 1
        let body = try block(until: [.kwEmpacar], opener: line)
        functionDepth -= 1
        try expect(.kwEmpacar, "'empacar'")
        return FuncDef(name: name, params: params, body: body, line: line)
    }

    private mutating func constructorDef() throws -> FuncDef {
        let line = advance().line                      // 'semilla'
        let params = try parameters()
        try expect(.colon, "':'")
        functionDepth += 1
        let body = try block(until: [.kwEmpacar], opener: line)
        functionDepth -= 1
        try expect(.kwEmpacar, "'empacar'")
        return FuncDef(name: "semilla", params: params, body: body, line: line)
    }

    private mutating func classDecl() throws -> ClassDecl {
        let line = advance().line                      // 'finca'
        let name = try expect(.id, "a class name").lexeme
        var superName: String? = nil
        if match(.kwInjerto) { superName = try expect(.id, "a parent class name").lexeme }
        try expect(.colon, "':'")
        var constructor: FuncDef? = nil
        var methods: [FuncDef] = []
        while !check(.kwEmpacar) {
            if check(.eof) {
                throw Diagnostic(.syntax, current.line,
                                 "expected 'empacar' to close the class opened on line \(line)")
            }
            if check(.kwSemilla) {
                if constructor != nil { throw fail("a class can only have one 'semilla'") }
                constructor = try constructorDef()
            } else if check(.kwReceta) {
                methods.append(try functionDef())
            } else {
                throw fail("expected 'semilla', 'receta' or 'empacar' inside a class")
            }
        }
        advance()                                      // 'empacar'
        return ClassDecl(name: name, superName: superName, constructor: constructor,
                         methods: methods, line: line)
    }

    // MARK: - Expresiones (de menor a mayor precedencia)

    private mutating func expression() throws -> Expr { try orExpr() }

    private mutating func orExpr() throws -> Expr {
        var left = try andExpr()
        while check(.or) {
            let line = advance().line
            left = .logical(false, left, try andExpr(), line)
        }
        return left
    }

    private mutating func andExpr() throws -> Expr {
        var left = try notExpr()
        while check(.and) {
            let line = advance().line
            left = .logical(true, left, try notExpr(), line)
        }
        return left
    }

    private mutating func notExpr() throws -> Expr {
        if check(.not) {
            let line = advance().line
            return .unary(.not, try notExpr(), line)
        }
        return try comparison()
    }

    private mutating func comparison() throws -> Expr {
        let left = try additive()
        let op: BinOp?
        switch current.type {
        case .gt: op = .gt
        case .lt: op = .lt
        case .ge: op = .ge
        case .le: op = .le
        case .eq: op = .eq
        case .ne: op = .ne
        default: op = nil
        }
        if let op = op {
            let line = advance().line
            return .binary(op, left, try additive(), line)
        }
        return left
    }

    private mutating func additive() throws -> Expr {
        var left = try term()
        while check(.plus) || check(.minus) {
            let token = advance()
            let right = try term()
            left = .binary(token.type == .plus ? .add : .sub, left, right, token.line)
        }
        return left
    }

    private mutating func term() throws -> Expr {
        var left = try unary()
        while check(.star) || check(.slash) || check(.percent) {
            let token = advance()
            let right = try unary()
            let op: BinOp = token.type == .star ? .mul : (token.type == .slash ? .div : .mod)
            left = .binary(op, left, right, token.line)
        }
        return left
    }

    private mutating func unary() throws -> Expr {
        if check(.minus) {
            let line = advance().line
            return .unary(.neg, try unary(), line)
        }
        return try postfix()
    }

    private mutating func postfix() throws -> Expr {
        var expr = try primary()
        while true {
            let line = current.line
            if match(.lbracket) {
                let index = try expression()
                try expect(.rbracket, "']'")
                expr = .index(expr, index, line)
            } else if match(.dot) {
                let name = try expect(.id, "an attribute or method name").lexeme
                expr = .member(expr, name, line)
            } else if check(.lparen) {
                expr = .call(expr, try arguments(), line)
            } else {
                break
            }
        }
        return expr
    }

    private mutating func primary() throws -> Expr {
        let token = current
        switch token.type {
        case .intNumber:
            advance()
            guard let value = Int(token.lexeme) else {
                throw Diagnostic(.syntax, token.line, "integer literal out of range")
            }
            return .literal(.int(value))
        case .realNumber:
            advance()
            return .literal(.real(Double(token.lexeme) ?? 0))
        case .string:
            advance()
            return .literal(.string(token.lexeme))
        case .kwFresco:
            advance()
            return .literal(.bool(true))
        case .kwRancio:
            advance()
            return .literal(.bool(false))
        case .kwVacio:
            advance()
            return .literal(.null)
        case .id:
            advance()
            return .variable(token.lexeme, token.line)
        case .kwCafetal:
            advance()
            return .this(token.line)
        case .lparen:
            advance()
            let inner = try expression()
            try expect(.rparen, "')'")
            return inner
        case .lbracket:
            advance()
            var items: [Expr] = []
            if !check(.rbracket) {
                repeat {
                    items.append(try expression())
                } while match(.comma)
            }
            try expect(.rbracket, "']'")
            return .array(items, token.line)
        case .kwPlantar:
            advance()
            let name = try expect(.id, "a class name").lexeme
            return .newObject(name, try arguments(), token.line)
        case .kwBarista:
            advance()
            let args = try arguments()
            if args.count > 1 { throw Diagnostic(.syntax, token.line, "'barista' takes at most one argument") }
            return .input(args.first, token.line)
        case .kwMedida:
            advance()
            let args = try arguments()
            if args.count != 1 { throw Diagnostic(.syntax, token.line, "'medida' takes exactly one argument") }
            return .length(args[0], token.line)
        case .kwRaiz:
            advance()
            if check(.lparen) {
                return .superCall(nil, try arguments(), token.line)
            }
            try expect(.dot, "'(' or '.' after 'raiz'")
            let method = try expect(.id, "a parent method name").lexeme
            return .superCall(method, try arguments(), token.line)
        default:
            throw fail("expected an expression")
        }
    }
}