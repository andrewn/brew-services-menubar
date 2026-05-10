//
//  BrewServices.swift
//  BrewServicesMenubar
//
//  Pure value types and helpers for talking to `brew services`.
//  Kept free of AppKit so it can be unit-tested without a GUI.
//

import Foundation

enum BrewError: Error, Equatable {
    case homebrewNotFound
    case launchFailed(String)
    case commandFailed(exitCode: Int32, stderr: String)
    case decodingFailed(String)
}

enum ServiceState: String, Decodable, Equatable {
    case started
    case stopped
    case none
    case error
    case scheduled
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ServiceState(rawValue: raw) ?? .unknown
    }
}

struct BrewService: Decodable, Equatable {
    let name: String
    let status: ServiceState
    let user: String?
    let file: String?
}

enum BrewServicesParser {
    static func parse(_ data: Data) throws -> [BrewService] {
        do {
            return try JSONDecoder().decode([BrewService].self, from: data)
        } catch {
            throw BrewError.decodingFailed(String(describing: error))
        }
    }
}

protocol ExecutableProbe {
    func isExecutableFile(atPath path: String) -> Bool
}

extension FileManager: ExecutableProbe {}

enum BrewLocator {
    static let defaultsKey = "brewExecutable"

    static var defaultPaths: [String] {
        #if arch(arm64)
        return ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        #else
        return ["/usr/local/bin/brew", "/opt/homebrew/bin/brew"]
        #endif
    }

    /// Resolve the brew executable from a value pulled out of `UserDefaults`
    /// (which may be a `[String]`, a single `String`, or `nil`), probing
    /// each candidate via the supplied `ExecutableProbe`.
    static func locate(rawDefault: Any?, probe: ExecutableProbe = FileManager.default) -> URL? {
        let candidates: [String]
        if let array = rawDefault as? [String] {
            candidates = array
        } else if let single = rawDefault as? String {
            candidates = [single]
        } else {
            candidates = []
        }

        for path in candidates where probe.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
