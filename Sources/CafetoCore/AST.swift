enum UnaryOp { case neg, not }
enum BinOp { case add, sub, mul, div, mod, gt, lt, ge, le, eq, ne }

indirect enum Expr {
    case literal(Value)
    case variable(String, Int)
    case this(Int)
    case array([Expr], Int)
    case index(Expr, Expr, Int)
    case member(Expr, String, Int)
    case call(Expr, [Expr], Int)
    case newObject(String, [Expr], Int)
    case superCall(String?, [Expr], Int)
    case input(Expr?, Int)
    case length(Expr, Int)
    case unary(UnaryOp, Expr, Int)
    case binary(BinOp, Expr, Expr, Int)
    case logical(Bool, Expr, Expr, Int)          // Bool = esAnd

    /// ¿Puede usarse como sentencia suelta?
    var isCallLike: Bool {
        switch self {
        case .call, .superCall, .input, .newObject: return true
        default: return false
        }
    }
}

struct Branch {
    let condition: Expr
    let body: [Stmt]
}

final class FuncDef {
    let name: String
    let params: [String]
    let body: [Stmt]
    let line: Int
    init(name: String, params: [String], body: [Stmt], line: Int) {
        self.name = name
        self.params = params
        self.body = body
        self.line = line
    }
}

final class ClassDecl {
    let name: String
    let superName: String?
    let constructor: FuncDef?
    let methods: [FuncDef]
    let line: Int
    init(name: String, superName: String?, constructor: FuncDef?, methods: [FuncDef], line: Int) {
        self.name = name
        self.superName = superName
        self.constructor = constructor
        self.methods = methods
        self.line = line
    }
}

indirect enum Stmt {
    case declare(String, Expr?, Int)
    case assign(Expr, Expr, Int)
    case expression(Expr, Int)
    case show([Expr], Int)
    case ifStmt([Branch], [Stmt]?, Int)
    case whileStmt(Expr, [Stmt], Int)
    case forStmt(String, Expr, Expr, [Stmt], Int)
    case breakStmt(Int)
    case continueStmt(Int)
    case returnStmt(Expr?, Int)
    case funcDecl(FuncDef)
    case classDecl(ClassDecl)
    case tryStmt([Stmt], String?, [Stmt]?, [Stmt]?, Int)
    case throwStmt(Expr, Int)
}