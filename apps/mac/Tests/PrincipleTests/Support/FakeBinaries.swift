import Foundation

@testable import PrincipleCore


/// Answers by the first recognisable argument, so the checker's two probes can be
/// stubbed independently without touching a real binary.
struct StubRunner: CommandRunning {
    var responses: [String: CommandOutput] = [:]

    static let loggedIn = StubRunner(responses: [
        "--version": CommandOutput(status: 0, standardOutput: "2.1.233 (Claude Code)\n"),
        "auth status": CommandOutput(status: 0, standardOutput: "{\"loggedIn\":true,\"subscriptionType\":\"max\"}"),
    ])

    func run(executable: URL, arguments: [String]) throws -> CommandOutput {
        guard let response = responses[arguments.joined(separator: " ")] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return response
    }
}

/// Temp-directory sandbox for fake `claude` binaries.
struct FakeBinaries {
    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("principle-engine-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func path(_ relative: String) -> String { root.appendingPathComponent(relative).path }

    @discardableResult
    func makeExecutable(named name: String, in folder: String) throws -> URL {
        try makeFile(named: name, in: folder, executable: true)
    }

    @discardableResult
    func makeFile(named name: String, in folder: String, executable: Bool, contents: String = "#!/bin/sh\n") throws
        -> URL
    {
        let directory = root.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: file.path)
        return file
    }

    func makeDirectory(_ relative: String) throws -> URL {
        let directory = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}
