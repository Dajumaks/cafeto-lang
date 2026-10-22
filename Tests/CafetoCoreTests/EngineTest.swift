import XCTest
@testable import CafetoCore

final class EngineTests: XCTestCase {
    private func run(_ lines: [String], input: [String] = []) -> (ok: Bool, out: String, err: String) {
        var out = ""
        var err = ""
        var queue = input
        let engine = CafetoEngine(
            showTokens: false,
            output: { out += $0 },
            errorOutput: { err += $0 + "\n" },
            input: { queue.isEmpty ? nil : queue.removeFirst() }
        )
        let ok = engine.run(source: lines.joined(separator: "\n"))
        return (ok, out, err)
    }

    func testConditional() {
        let r = run([
            "sembrar x brota 20",
            "catar x amargo 5:",
            "    servir(\"Greater than 5\")",
            "ristretto:",
            "    servir(\"Less than or equal to 5\")",
            "empacar",
        ])
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.out, "Greater than 5\n")
    }

    func testFunctionsArraysAndLoops() {
        let r = run([
            "receta sumar(lista, n):",
            "    sembrar total brota 0",
            "    recolectar i vivero 0 taza n - 1:",
            "        total brota total + lista[i]",
            "    empacar",
            "    entregar total",
            "empacar",
            "servir(\"The sum is \" + sumar([4, 8, 15, 16], 4))",
        ])
        XCTAssertEqual(r.out, "The sum is 43\n")
    }

    func testClassesAndExceptions() {
        let r = run([
            "finca Cuenta:",
            "    semilla(titular, saldo):",
            "        cafetal.titular brota titular",
            "        cafetal.saldo brota saldo",
            "    empacar",
            "    receta retirar(valor):",
            "        catar valor amargo cafetal.saldo:",
            "            volcar \"Insufficient balance\"",
            "        empacar",
            "        cafetal.saldo brota cafetal.saldo - valor",
            "        entregar cafetal.saldo",
            "    empacar",
            "empacar",
            "sembrar c brota plantar Cuenta(\"Ana\", 100)",
            "preparar:",
            "    servir(\"New balance: \" + c.retirar(30))",
            "    servir(\"New balance: \" + c.retirar(200))",
            "derrame error:",
            "    servir(\"Error: \" + error)",
            "lavar:",
            "    servir(\"Operation finished\")",
            "empacar",
        ])
        XCTAssertEqual(r.out, "New balance: 70\nError: Insufficient balance\nOperation finished\n")
    }

    func testDivisionByZeroReportsLine() {
        let r = run(["servir(\"antes\")", "servir(1 / 0)"])
        XCTAssertFalse(r.ok)
        XCTAssertEqual(r.out, "antes\n")
        XCTAssertTrue(r.err.contains("Runtime error on line 2: division by zero"))
    }

    func testSyntaxErrorMissingEnd() {
        let r = run(["catar fresco:", "    servir(1)"])
        XCTAssertFalse(r.ok)
        XCTAssertTrue(r.err.contains("Syntax error on line 2"))
    }

    func testLexicalError() {
        let r = run(["sembrar a brota 1 @"])
        XCTAssertFalse(r.ok)
        XCTAssertTrue(r.err.contains("Lexical error on line 1: unrecognized symbol '@'"))
    }

    func testInput() {
        let r = run(["sembrar n brota barista()", "servir(n + 1)"], input: ["41"])
        XCTAssertEqual(r.out, "42\n")
    }
}