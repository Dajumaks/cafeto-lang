/// Tabla de símbolos con alcance léxico encadenado.
final class Environment {
    private var values: [String: Value] = [:]
    let parent: Environment?

    init(parent: Environment? = nil) {
        self.parent = parent
    }

    func define(_ name: String, _ value: Value) {
        values[name] = value
    }

    func isDefinedLocally(_ name: String) -> Bool {
        values[name] != nil
    }

    func get(_ name: String) -> Value? {
        values[name] ?? parent?.get(name)
    }

    /// Asigna a la variable existente más cercana. Devuelve false si no existe.
    func assign(_ name: String, _ value: Value) -> Bool {
        if values[name] != nil {
            values[name] = value
            return true
        }
        return parent?.assign(name, value) ?? false
    }
}