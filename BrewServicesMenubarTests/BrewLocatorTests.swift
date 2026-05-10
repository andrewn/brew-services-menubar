//
//  BrewLocatorTests.swift
//  BrewServicesMenubarTests
//

import XCTest
@testable import BrewServicesMenubar

private final class StubProbe: ExecutableProbe {
    let executable: Set<String>
    init(_ executable: [String]) { self.executable = Set(executable) }
    func isExecutableFile(atPath path: String) -> Bool { executable.contains(path) }
}

final class BrewLocatorTests: XCTestCase {

    func testReturnsFirstExecutableFromArray() {
        let probe = StubProbe(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"])
        let url = BrewLocator.locate(
            rawDefault: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"],
            probe: probe
        )
        XCTAssertEqual(url?.path, "/opt/homebrew/bin/brew")
    }

    func testFallsThroughToLaterCandidate() {
        let probe = StubProbe(["/usr/local/bin/brew"])
        let url = BrewLocator.locate(
            rawDefault: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"],
            probe: probe
        )
        XCTAssertEqual(url?.path, "/usr/local/bin/brew")
    }

    func testHonoursLegacyStringDefault() {
        let probe = StubProbe(["/custom/path/brew"])
        let url = BrewLocator.locate(rawDefault: "/custom/path/brew", probe: probe)
        XCTAssertEqual(url?.path, "/custom/path/brew")
    }

    func testReturnsNilWhenNoCandidateExecutable() {
        let probe = StubProbe([])
        XCTAssertNil(BrewLocator.locate(
            rawDefault: ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"],
            probe: probe
        ))
    }

    func testReturnsNilForUnsupportedDefault() {
        let probe = StubProbe(["/usr/local/bin/brew"])
        XCTAssertNil(BrewLocator.locate(rawDefault: 42, probe: probe))
        XCTAssertNil(BrewLocator.locate(rawDefault: nil, probe: probe))
    }

    func testDefaultPathsContainsBothLocations() {
        XCTAssertTrue(BrewLocator.defaultPaths.contains("/opt/homebrew/bin/brew"))
        XCTAssertTrue(BrewLocator.defaultPaths.contains("/usr/local/bin/brew"))
    }
}
