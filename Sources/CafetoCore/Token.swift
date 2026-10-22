/// Todos los tipos de token del lenguaje Cafeto.
enum TokenType: String {
    // Palabras reservadas
    case kwSembrar = "KW_SEMBRAR"           // declarar variable
    case kwCatar = "KW_CATAR"               // if
    case kwMacchiato = "KW_MACCHIATO"       // else if
    case kwRistretto = "KW_RISTRETTO"       // else
    case kwColar = "KW_COLAR"               // while
    case kwRecolectar = "KW_RECOLECTAR"     // for
    case kwVivero = "KW_VIVERO"             // desde
    case kwTaza = "KW_TAZA"                 // hasta
    case kwDecantar = "KW_DECANTAR"         // break
    case kwFiltrar = "KW_FILTRAR"           // continue
    case kwBarista = "KW_BARISTA"           // leer
    case kwServir = "KW_SERVIR"             // mostrar
    case kwReceta = "KW_RECETA"             // funcion
    case kwEntregar = "KW_ENTREGAR"         // return
    case kwFinca = "KW_FINCA"               // clase
    case kwSemilla = "KW_SEMILLA"           // constructor
    case kwPlantar = "KW_PLANTAR"           // new
    case kwCafetal = "KW_CAFETAL"           // this
    case kwInjerto = "KW_INJERTO"           // herencia
    case kwRaiz = "KW_RAIZ"                 // super
    case kwPreparar = "KW_PREPARAR"         // try
    case kwDerrame = "KW_DERRAME"           // catch
    case kwLavar = "KW_LAVAR"               // finally
    case kwVolcar = "KW_VOLCAR"             // throw
    case kwMedida = "KW_MEDIDA"             // longitud
    case kwEmpacar = "KW_EMPACAR"           // fin de bloque
    case kwFresco = "KW_FRESCO"             // true
    case kwRancio = "KW_RANCIO"             // false
    case kwVacio = "KW_VACIO"               // nil

    // Operadores
    case assign = "ASSIGN"                  // brota
    case and = "AND"                        // leche
    case or = "OR"                          // azucar
    case not = "NOT"                        // descafeinado
    case gt = "GT"                          // amargo
    case lt = "LT"                          // dulce
    case ge = "GE"                          // intenso
    case le = "LE"                          // ligero
    case eq = "EQ"                          // mismo
    case ne = "NE"                          // distinto
    case plus = "PLUS"
    case minus = "MINUS"
    case star = "STAR"
    case slash = "SLASH"
    case percent = "PERCENT"

    // Delimitadores
    case lparen = "LPAREN"
    case rparen = "RPAREN"
    case lbracket = "LBRACKET"
    case rbracket = "RBRACKET"
    case comma = "COMMA"
    case dot = "DOT"
    case colon = "COLON"

    // Literales e identificadores
    case id = "ID"
    case intNumber = "INT_NUMBER"
    case realNumber = "REAL_NUMBER"
    case string = "STRING"
    case eof = "EOF"
}

/// Palabras reservadas -> tipo de token (aquí vive TODO el vocabulario del lenguaje).
let keywordTable: [String: TokenType] = [
    "sembrar": .kwSembrar,
    "catar": .kwCatar,
    "macchiato": .kwMacchiato,
    "ristretto": .kwRistretto,
    "colar": .kwColar,
    "recolectar": .kwRecolectar,
    "vivero": .kwVivero,
    "taza": .kwTaza,
    "decantar": .kwDecantar,
    "filtrar": .kwFiltrar,
    "barista": .kwBarista,
    "servir": .kwServir,
    "receta": .kwReceta,
    "entregar": .kwEntregar,
    "finca": .kwFinca,
    "semilla": .kwSemilla,
    "plantar": .kwPlantar,
    "cafetal": .kwCafetal,
    "injerto": .kwInjerto,
    "raiz": .kwRaiz,
    "preparar": .kwPreparar,
    "derrame": .kwDerrame,
    "lavar": .kwLavar,
    "volcar": .kwVolcar,
    "medida": .kwMedida,
    "empacar": .kwEmpacar,
    "fresco": .kwFresco,
    "rancio": .kwRancio,
    "vacio": .kwVacio,
    "brota": .assign,
    "leche": .and,
    "azucar": .or,
    "descafeinado": .not,
    "amargo": .gt,
    "dulce": .lt,
    "intenso": .ge,
    "ligero": .le,
    "mismo": .eq,
    "distinto": .ne,
]

struct Token: CustomStringConvertible {
    let type: TokenType
    let lexeme: String
    let line: Int

    init(_ type: TokenType, _ lexeme: String, _ line: Int) {
        self.type = type
        self.lexeme = lexeme
        self.line = line
    }

    /// Formato pedido por el enunciado: `[line 1] KW_SEMBRAR sembrar`
    var description: String {
        let shown = type == .string ? "\"\(lexeme)\"" : lexeme
        return "[line \(line)] \(type.rawValue) \(shown)"
    }
}