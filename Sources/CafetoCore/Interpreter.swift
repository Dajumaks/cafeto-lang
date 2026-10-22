/// Resultado de ejecutar una sentencia (control de flujo sin usar excepciones de Swift).
private enum Flow {
    case normal
    case brk
    case cont
    case ret(Value)
}

/// Intérprete que recorre el AST.
final class Interpreter {
    private let globals = Environment()
    private let output: (String) -> Void
    private let input: () -> String?
    private var callDepth = 0
    private let maxCallDepth = 2500

    init(output: @escaping (String) -> Void, input: @escaping () -> String?) {
        self.output = output
        self.input = input
    }

    func run(_ program: [Stmt]) throws {
        // Las funciones y clases de primer nivel se registran antes de ejecutar.
        for statement in program {
            switch statement {
            case .funcDecl(let def): globals.define(def.name, .function(def))
            case .classDecl(let decl): try defineClass(decl, in: globals)
            default: break
            }
        }
        _ = try execute(program, in: globals)
    }

    private func runtime(_ line: Int, _ message: String) -> Diagnostic {
        Diagnostic(.runtime, line, message)
    }

    // MARK: - Sentencias

    private func execute(_ statements: [Stmt], in env: Environment) throws -> Flow {
        for statement in statements {
            let flow = try exec(statement, in: env)
            if case .normal = flow { continue }
            return flow
        }
        return .normal
    }

    private func exec(_ stmt: Stmt, in env: Environment) throws -> Flow {
        switch stmt {
        case .declare(let name, let initial, let line):
            if env.isDefinedLocally(name) {
                throw runtime(line, "variable '\(name)' is already declared in this scope")
            }
            var value = Value.null
            if let initial = initial { value = try eval(initial, env) }
            env.define(name, value)

        case .assign(let target, let valueExpr, let line):
            let value = try eval(valueExpr, env)
            try assign(target, value, env, line)

        case .expression(let expr, _):
            _ = try eval(expr, env)

        case .show(let args, _):
            let values = try evalArgs(args, env)
            output(values.map { $0.display }.joined(separator: " ") + "\n")

        case .ifStmt(let branches, let elseBody, let line):
            for branch in branches {
                if try condition(branch.condition, env, line) {
                    return try execute(branch.body, in: Environment(parent: env))
                }
            }
            if let elseBody = elseBody {
                return try execute(elseBody, in: Environment(parent: env))
            }

        case .whileStmt(let cond, let body, let line):
            loop: while try condition(cond, env, line) {
                let flow = try execute(body, in: Environment(parent: env))
                switch flow {
                case .brk: break loop
                case .ret: return flow
                case .cont, .normal: break
                }
            }

        case .forStmt(let name, let fromExpr, let toExpr, let body, let line):
            let from = try eval(fromExpr, env)
            let to = try eval(toExpr, env)
            guard case .int(let start) = from, case .int(let end) = to else {
                throw runtime(line, "the bounds of 'recolectar' must be integers")
            }
            var i = start
            loop: while i <= end {
                let loopEnv = Environment(parent: env)
                loopEnv.define(name, .int(i))
                let flow = try execute(body, in: loopEnv)
                switch flow {
                case .brk: break loop
                case .ret: return flow
                case .cont, .normal: break
                }
                if i == Int.max { break }
                i += 1
            }

        case .breakStmt:
            return .brk

        case .continueStmt:
            return .cont

        case .returnStmt(let expr, _):
            var value = Value.null
            if let expr = expr { value = try eval(expr, env) }
            return .ret(value)

        case .funcDecl(let def):
            if env !== globals { env.define(def.name, .function(def)) }

        case .classDecl(let decl):
            if env !== globals { try defineClass(decl, in: env) }

        case .tryStmt(let body, let catchVar, let catchBody, let finallyBody, _):
            return try execTry(body, catchVar, catchBody, finallyBody, env)

        case .throwStmt(let expr, let line):
            throw ThrownValue(value: try eval(expr, env), line: line)
        }
        return .normal
    }

    private func execTry(_ body: [Stmt], _ catchVar: String?, _ catchBody: [Stmt]?,
                         _ finallyBody: [Stmt]?, _ env: Environment) throws -> Flow {
        var result: Flow = .normal
        var pending: Error?
        do {
            result = try execute(body, in: Environment(parent: env))
        } catch {
            if let handler = catchBody, let value = caughtValue(error) {
                let handlerEnv = Environment(parent: env)
                if let name = catchVar { handlerEnv.define(name, value) }
                do {
                    result = try execute(handler, in: handlerEnv)
                } catch {
                    pending = error
                }
            } else {
                pending = error
            }
        }
        if let finallyBody = finallyBody {
            let flow = try execute(finallyBody, in: Environment(parent: env))
            if case .normal = flow {} else { return flow }
        }
        if let pending = pending { throw pending }
        return result
    }

    /// Los errores de ejecución se atrapan como texto; `volcar` atrapa el valor lanzado.
    private func caughtValue(_ error: Error) -> Value? {
        if let diagnostic = error as? Diagnostic {
            return diagnostic.kind == .runtime ? .string(diagnostic.message) : nil
        }
        if let thrown = error as? ThrownValue { return thrown.value }
        return nil
    }

    private func defineClass(_ decl: ClassDecl, in env: Environment) throws {
        var parent: ClassValue? = nil
        if let superName = decl.superName {
            guard let value = env.get(superName), case .classRef(let cls) = value else {
                throw runtime(decl.line, "parent class '\(superName)' is not declared")
            }
            parent = cls
        }
        var methods: [String: FuncDef] = [:]
        for method in decl.methods { methods[method.name] = method }
        let cls = ClassValue(name: decl.name, superclass: parent,
                             constructor: decl.constructor, methods: methods)
        env.define(decl.name, .classRef(cls))
    }

    private func condition(_ expr: Expr, _ env: Environment, _ line: Int) throws -> Bool {
        let value = try eval(expr, env)
        guard case .bool(let b) = value else {
            throw runtime(line, "the condition must be boolean, got \(value.typeName)")
        }
        return b
    }

    private func assign(_ target: Expr, _ value: Value, _ env: Environment, _ line: Int) throws {
        switch target {
        case .variable(let name, let l):
            if !env.assign(name, value) {
                throw runtime(l, "variable '\(name)' is not declared")
            }
        case .index(let arrayExpr, let indexExpr, let l):
            let container = try eval(arrayExpr, env)
            let index = try eval(indexExpr, env)
            guard case .array(let box) = container else {
                throw runtime(l, "only arrays support index assignment (got \(container.typeName))")
            }
            let i = try checkIndex(index, count: box.items.count, line: l)
            box.items[i] = value
        case .member(let objectExpr, let name, let l):
            let object = try eval(objectExpr, env)
            guard case .object(let instance) = object else {
                throw runtime(l, "cannot set attribute '\(name)' on \(object.typeName)")
            }
            instance.fields[name] = value
        default:
            throw runtime(line, "invalid assignment target")
        }
    }

    private func checkIndex(_ value: Value, count: Int, line: Int) throws -> Int {
        guard case .int(let i) = value else {
            throw runtime(line, "the index must be an integer, got \(value.typeName)")
        }
        guard i >= 0 && i < count else {
            throw runtime(line, "index out of range: \(i) (size \(count))")
        }
        return i
    }

    // MARK: - Expresiones

    private func evalArgs(_ exprs: [Expr], _ env: Environment) throws -> [Value] {
        var values: [Value] = []
        for expr in exprs { values.append(try eval(expr, env)) }
        return values
    }

    private func eval(_ expr: Expr, _ env: Environment) throws -> Value {
        switch expr {
        case .literal(let value):
            return value

        case .variable(let name, let line):
            guard let value = env.get(name) else {
                throw runtime(line, "variable '\(name)' is not declared")
            }
            return value

        case .this(let line):
            guard let value = env.get("cafetal") else {
                throw runtime(line, "'cafetal' can only be used inside a constructor or method")
            }
            return value

        case .array(let items, _):
            let values = try evalArgs(items, env)
            return .array(ArrayBox(values))

        case .index(let containerExpr, let indexExpr, let line):
            let container = try eval(containerExpr, env)
            let index = try eval(indexExpr, env)
            switch container {
            case .array(let box):
                let i = try checkIndex(index, count: box.items.count, line: line)
                return box.items[i]
            case .string(let s):
                let characters = Array(s)
                let i = try checkIndex(index, count: characters.count, line: line)
                return .string(String(characters[i]))
            default:
                throw runtime(line, "cannot index a value of type \(container.typeName)")
            }

        case .member(let objectExpr, let name, let line):
            let object = try eval(objectExpr, env)
            guard case .object(let instance) = object else {
                throw runtime(line, "cannot read attribute '\(name)' of \(object.typeName)")
            }
            guard let value = instance.fields[name] else {
                throw runtime(line, "attribute '\(name)' does not exist in \(instance.cls.name)")
            }
            return value

        case .call(let callee, let argExprs, let line):
            return try evalCall(callee, argExprs, env, line)

        case .newObject(let name, let argExprs, let line):
            guard let value = env.get(name), case .classRef(let cls) = value else {
                throw runtime(line, "class '\(name)' is not declared")
            }
            let instance = Instance(cls: cls)
            let args = try evalArgs(argExprs, env)
            if let (ctor, owner) = cls.findConstructor() {
                _ = try call(ctor, args: args, this: instance, owner: owner, line: line)
            } else if !args.isEmpty {
                throw runtime(line, "class '\(name)' has no 'semilla' but received \(args.count) argument(s)")
            }
            return .object(instance)

        case .superCall(let method, let argExprs, let line):
            guard let ownerValue = env.get("%owner"), case .classRef(let owner) = ownerValue,
                  let thisValue = env.get("cafetal"), case .object(let instance) = thisValue else {
                throw runtime(line, "'raiz' can only be used inside a constructor or method")
            }
            guard let parent = owner.superclass else {
                throw runtime(line, "class '\(owner.name)' has no parent class")
            }
            let args = try evalArgs(argExprs, env)
            if let method = method {
                guard let (def, definingClass) = parent.findMethod(method) else {
                    throw runtime(line, "method '\(method)' does not exist in the parent class")
                }
                return try call(def, args: args, this: instance, owner: definingClass, line: line)
            }
            if let (ctor, definingClass) = parent.findConstructor() {
                _ = try call(ctor, args: args, this: instance, owner: definingClass, line: line)
            } else if !args.isEmpty {
                throw runtime(line, "the parent class has no 'semilla' but received \(args.count) argument(s)")
            }
            return .null

        case .input(let promptExpr, _):
            if let promptExpr = promptExpr {
                output(try eval(promptExpr, env).display)
            }
            guard let text = input() else { return .string("") }
            return parseInput(text)

        case .length(let valueExpr, let line):
            let value = try eval(valueExpr, env)
            switch value {
            case .array(let box): return .int(box.items.count)
            case .string(let s): return .int(s.count)
            default: throw runtime(line, "'medida' needs an array or a string, got \(value.typeName)")
            }

        case .unary(let op, let operandExpr, let line):
            let operand = try eval(operandExpr, env)
            switch op {
            case .neg:
                if case .int(let i) = operand { return .int(-i) }
                if case .real(let d) = operand { return .real(-d) }
                throw runtime(line, "cannot negate a value of type \(operand.typeName)")
            case .not:
                guard case .bool(let b) = operand else {
                    throw runtime(line, "'descafeinado' needs a boolean, got \(operand.typeName)")
                }
                return .bool(!b)
            }

        case .binary(let op, let leftExpr, let rightExpr, let line):
            let left = try eval(leftExpr, env)
            let right = try eval(rightExpr, env)
            return try binary(op, left, right, line)

        case .logical(let isAnd, let leftExpr, let rightExpr, let line):
            let left = try eval(leftExpr, env)
            guard case .bool(let l) = left else {
                throw runtime(line, "logical operators need booleans, got \(left.typeName)")
            }
            if isAnd && !l { return .bool(false) }
            if !isAnd && l { return .bool(true) }
            let right = try eval(rightExpr, env)
            guard case .bool(let r) = right else {
                throw runtime(line, "logical operators need booleans, got \(right.typeName)")
            }
            return .bool(r)
        }
    }

    /// El texto leído se convierte a entero o real si tiene forma numérica.
    private func parseInput(_ text: String) -> Value {
        if let i = Int(text) { return .int(i) }
        if text.contains(where: { $0.isNumber }), let d = Double(text) { return .real(d) }
        return .string(text)
    }

    // MARK: - Llamadas

    private func evalCall(_ callee: Expr, _ argExprs: [Expr], _ env: Environment, _ line: Int) throws -> Value {
        switch callee {
        case .member(let objectExpr, let name, let memberLine):
            let object = try eval(objectExpr, env)
            guard case .object(let instance) = object else {
                throw runtime(memberLine, "cannot call method '\(name)' on \(object.typeName)")
            }
            guard let (def, owner) = instance.cls.findMethod(name) else {
                throw runtime(memberLine, "method '\(name)' does not exist in \(instance.cls.name)")
            }
            let args = try evalArgs(argExprs, env)
            return try call(def, args: args, this: instance, owner: owner, line: line)

        case .variable(let name, let variableLine):
            guard let value = env.get(name) else {
                throw runtime(variableLine, "function '\(name)' is not declared")
            }
            guard case .function(let def) = value else {
                throw runtime(variableLine, "'\(name)' is not a function")
            }
            let args = try evalArgs(argExprs, env)
            return try call(def, args: args, this: nil, owner: nil, line: line)

        default:
            throw runtime(line, "this expression cannot be called")
        }
    }

    private func call(_ def: FuncDef, args: [Value], this: Instance?, owner: ClassValue?, line: Int) throws -> Value {
        guard args.count == def.params.count else {
            throw runtime(line, "'\(def.name)' expects \(def.params.count) argument(s) but received \(args.count)")
        }
        callDepth += 1
        defer { callDepth -= 1 }
        if callDepth > maxCallDepth {
            throw runtime(line, "stack overflow: recursion is too deep")
        }
        let env = Environment(parent: globals)
        for (param, arg) in zip(def.params, args) { env.define(param, arg) }
        if let this = this { env.define("cafetal", .object(this)) }
        if let owner = owner { env.define("%owner", .classRef(owner)) }
        let flow = try execute(def.body, in: env)
        if case .ret(let value) = flow { return value }
        return .null
    }

    // MARK: - Operadores

    private func numeric(_ value: Value) -> Double? {
        switch value {
        case .int(let i): return Double(i)
        case .real(let d): return d
        default: return nil
        }
    }

    private func valuesEqual(_ a: Value, _ b: Value) -> Bool {
        switch (a, b) {
        case (.int(let x), .int(let y)): return x == y
        case (.real(let x), .real(let y)): return x == y
        case (.int(let x), .real(let y)): return Double(x) == y
        case (.real(let x), .int(let y)): return x == Double(y)
        case (.string(let x), .string(let y)): return x == y
        case (.bool(let x), .bool(let y)): return x == y
        case (.null, .null): return true
        case (.array(let x), .array(let y)): return x === y
        case (.object(let x), .object(let y)): return x === y
        default: return false
        }
    }

    private func binary(_ op: BinOp, _ left: Value, _ right: Value, _ line: Int) throws -> Value {
        switch op {
        case .eq: return .bool(valuesEqual(left, right))
        case .ne: return .bool(!valuesEqual(left, right))
        case .gt, .lt, .ge, .le: return try compare(op, left, right, line)
        case .add:
            if case .string = left { return .string(left.display + right.display) }
            if case .string = right { return .string(left.display + right.display) }
            fallthrough
        case .sub, .mul, .div, .mod:
            return try arithmetic(op, left, right, line)
        }
    }

    private func compare(_ op: BinOp, _ left: Value, _ right: Value, _ line: Int) throws -> Value {
        let order: Int
        if let x = numeric(left), let y = numeric(right) {
            order = x < y ? -1 : (x > y ? 1 : 0)
        } else if case .string(let x) = left, case .string(let y) = right {
            order = x < y ? -1 : (x > y ? 1 : 0)
        } else {
            throw runtime(line, "cannot compare \(left.typeName) with \(right.typeName)")
        }
        switch op {
        case .gt: return .bool(order > 0)
        case .lt: return .bool(order < 0)
        case .ge: return .bool(order >= 0)
        default: return .bool(order <= 0)
        }
    }

    private func arithmetic(_ op: BinOp, _ left: Value, _ right: Value, _ line: Int) throws -> Value {
        if case .int(let a) = left, case .int(let b) = right {
            let result: (partialValue: Int, overflow: Bool)
            switch op {
            case .add: result = a.addingReportingOverflow(b)
            case .sub: result = a.subtractingReportingOverflow(b)
            case .mul: result = a.multipliedReportingOverflow(by: b)
            case .div:
                if b == 0 { throw runtime(line, "division by zero") }
                result = a.dividedReportingOverflow(by: b)
            case .mod:
                if b == 0 { throw runtime(line, "division by zero") }
                result = a.remainderReportingOverflow(dividingBy: b)
            default: throw runtime(line, "invalid arithmetic operator")
            }
            if result.overflow { throw runtime(line, "integer overflow") }
            return .int(result.partialValue)
        }
        guard let x = numeric(left), let y = numeric(right) else {
            throw runtime(line, "invalid operands for arithmetic: \(left.typeName) and \(right.typeName)")
        }
        switch op {
        case .add: return .real(x + y)
        case .sub: return .real(x - y)
        case .mul: return .real(x * y)
        case .div:
            if y == 0 { throw runtime(line, "division by zero") }
            return .real(x / y)
        case .mod:
            if y == 0 { throw runtime(line, "division by zero") }
            return .real(x.truncatingRemainder(dividingBy: y))
        default:
            throw runtime(line, "invalid arithmetic operator")
        }
    }
}