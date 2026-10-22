enum Value {
    case int(Int)
    case real(Double)
    case string(String)
    case bool(Bool)
    case null
    case array(ArrayBox)
    case object(Instance)
    case function(FuncDef)
    case classRef(ClassValue)
}

final class ArrayBox {
    var items: [Value]
    init(_ items: [Value]) { self.items = items }
}

final class ClassValue {
    let name: String
    let superclass: ClassValue?
    let constructor: FuncDef?
    let methods: [String: FuncDef]

    init(name: String, superclass: ClassValue?, constructor: FuncDef?, methods: [String: FuncDef]) {
        self.name = name
        self.superclass = superclass
        self.constructor = constructor
        self.methods = methods
    }

    func findMethod(_ name: String) -> (FuncDef, ClassValue)? {
        if let method = methods[name] { return (method, self) }
        return superclass?.findMethod(name)
    }

    func findConstructor() -> (FuncDef, ClassValue)? {
        if let ctor = constructor { return (ctor, self) }
        return superclass?.findConstructor()
    }
}

final class Instance {
    let cls: ClassValue
    var fields: [String: Value] = [:]
    init(cls: ClassValue) { self.cls = cls }
}

extension Value {
    var typeName: String {
        switch self {
        case .int: return "integer"
        case .real: return "real"
        case .string: return "string"
        case .bool: return "boolean"
        case .null: return "vacio"
        case .array: return "array"
        case .object(let o): return "object of \(o.cls.name)"
        case .function: return "function"
        case .classRef: return "class"
        }
    }

    /// Texto usado por `servir` y por la concatenación con `+`.
    var display: String {
        switch self {
        case .int(let i): return String(i)
        case .real(let d): return String(d)
        case .string(let s): return s
        case .bool(let b): return b ? "fresco" : "rancio"
        case .null: return "vacio"
        case .array(let box): return "[" + box.items.map { $0.inspect }.joined(separator: ", ") + "]"
        case .object(let o): return "<\(o.cls.name)>"
        case .function(let f): return "<receta \(f.name)>"
        case .classRef(let c): return "<finca \(c.name)>"
        }
    }

    /// Igual que `display`, pero los strings llevan comillas (se usa dentro de arreglos).
    var inspect: String {
        if case .string(let s) = self { return "\"\(s)\"" }
        return display
    }
}