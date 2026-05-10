//
//  BrewServicesParserTests.swift
//  BrewServicesMenubarTests
//

import XCTest
@testable import BrewServicesMenubar

final class BrewServicesParserTests: XCTestCase {

    func testEmptyList() throws {
        let data = try fixture("services-empty")
        XCTAssertEqual(try BrewServicesParser.parse(data), [])
    }

    func testMixedStatuses() throws {
        let data = try fixture("services-mixed")
        let services = try BrewServicesParser.parse(data)
        XCTAssertEqual(services.count, 5)
        XCTAssertEqual(services[0].name, "postgresql@14")
        XCTAssertEqual(services[0].status, .started)
        XCTAssertEqual(services[0].user, "andrew")

        XCTAssertEqual(services[1].name, "redis")
        XCTAssertEqual(services[1].status, .stopped)
        XCTAssertNil(services[1].user)

        XCTAssertEqual(services[2].status, .none)
        XCTAssertEqual(services[3].status, .error)
        XCTAssertEqual(services[4].status, .scheduled)
    }

    func testUnknownStatusFallsBackToUnknown() throws {
        let json = """
        [{"name":"weird","status":"future-status","user":null,"file":null}]
        """.data(using: .utf8)!
        let services = try BrewServicesParser.parse(json)
        XCTAssertEqual(services.first?.status, .unknown)
    }

    func testMalformedJSONThrows() {
        let bad = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try BrewServicesParser.parse(bad)) { error in
            guard case BrewError.decodingFailed = error else {
                return XCTFail("expected decodingFailed, got \(error)")
            }
        }
    }

    func testMissingRequiredFieldThrows() {
        let json = """
        [{"status":"started"}]
        """.data(using: .utf8)!
        XCTAssertThrowsError(try BrewServicesParser.parse(json))
    }

    func testTolerantOfExtraFields() throws {
        let json = """
        [{"name":"a","status":"started","user":"u","file":"/f","future_field":42}]
        """.data(using: .utf8)!
        let services = try BrewServicesParser.parse(json)
        XCTAssertEqual(services.first?.name, "a")
    }

    // MARK: helpers

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "json"),
            "fixture \(name).json missing from test bundle"
        )
        return try Data(contentsOf: url)
    }
}
