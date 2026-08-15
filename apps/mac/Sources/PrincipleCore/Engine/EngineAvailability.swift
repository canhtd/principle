import Foundation

/// Whether this machine can actually run a turn right now.
public enum EngineAvailability: Sendable, Equatable {
    /// Binary found and logged in. Carries the reported CLI version.
    case ready(version: String)
    /// No `claude` binary at the override path or any known location.
    case notInstalled
    /// Binary found but not usable without the user doing something first;
    /// `guidance` is the Vietnamese sentence the UI shows verbatim.
    case loggedOut(guidance: String)
}

/// Result of a one-shot command. Kept dumb so tests can hand-build one.
public struct CommandOutput: Sendable, Equatable {
    public let status: Int32
    public let standardOutput: String
    public let standardError: String

    public init(status: Int32, standardOutput: String = "", standardError: String = "") {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// Seam that keeps the availability check testable without a real `claude` binary.
public protocol CommandRunning: Sendable {
    func run(executable: URL, arguments: [String]) throws -> CommandOutput
}

/// Finds the `claude` binary by absolute path.
///
/// An app launched from the Dock inherits none of the shell's `PATH`, so looking
/// the binary up by name would work in `swift run` and fail in the shipped bundle.
/// We only ever spawn via an absolute `executableURL`.
public enum EngineBinaryResolver {
    /// `~/.local/bin` first: on this machine that is the installation the engine
    /// behaviour was probed against, and it can differ from the Homebrew one.
    public static let defaultCandidates = [
        "~/.local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
        "/usr/bin/claude",
    ]

    /// An explicit override wins outright: if the user pointed Settings at a path,
    /// silently falling back to a different binary would hide their mistake.
    public static func resolve(
        override: String?,
        candidates: [String] = defaultCandidates,
        fileManager: FileManager = .default
    ) -> URL? {
        if let override, !override.trimmingCharacters(in: .whitespaces).isEmpty {
            return executable(at: override, fileManager: fileManager)
        }
        return candidates.lazy.compactMap { executable(at: $0, fileManager: fileManager) }.first
    }

    /// Expands a leading `~` against the process's home directory. Not shell
    /// expansion — a GUI app has no shell to do it.
    static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private static func executable(at path: String, fileManager: FileManager) -> URL? {
        let expanded = expand(path)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory),
            !isDirectory.boolValue,
            fileManager.isExecutableFile(atPath: expanded)
        else { return nil }
        return URL(fileURLWithPath: expanded)
    }
}

/// Runs KTD4's check: `--version` then `auth status`. Neither costs a model call,
/// so this runs at launch and again before every send.
public struct EngineAvailabilityChecker: Sendable {
    private let candidates: [String]
    private let runner: any CommandRunning

    public init(
        candidates: [String] = EngineBinaryResolver.defaultCandidates,
        runner: any CommandRunning = ProcessCommandRunner()
    ) {
        self.candidates = candidates
        self.runner = runner
    }

    public func check(overridePath: String? = nil) -> EngineAvailability {
        guard let binary = EngineBinaryResolver.resolve(override: overridePath, candidates: candidates) else {
            return .notInstalled
        }
        guard let version = try? runner.run(executable: binary, arguments: ["--version"]),
            version.status == 0
        else { return .notInstalled }

        guard let auth = try? runner.run(executable: binary, arguments: ["auth", "status"]),
            let loggedIn = Self.loggedIn(inJSON: auth.standardOutput)
        else {
            // Cannot prove the session is usable. Blocking with instructions beats
            // spawning a turn that dies on an auth prompt the user never sees.
            return .loggedOut(guidance: Self.unknownGuidance)
        }
        guard loggedIn else { return .loggedOut(guidance: Self.loggedOutGuidance) }
        return .ready(version: Self.version(from: version.standardOutput))
    }

    static let loggedOutGuidance =
        "Claude Code chưa đăng nhập. Mở Terminal, chạy `claude login`, rồi thử lại."
    static let unknownGuidance =
        "Không đọc được trạng thái đăng nhập của Claude Code. Mở Terminal, chạy `claude auth status` để kiểm tra, đăng nhập nếu cần, rồi thử lại."

    /// `claude auth status` prints `{"loggedIn":true,"subscriptionType":"max"}`,
    /// possibly with other lines around it.
    static func loggedIn(inJSON text: String) -> Bool? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return nil
        }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["loggedIn"] as? Bool
    }

    /// `claude --version` prints e.g. `2.1.233 (Claude Code)`.
    static func version(from output: String) -> String {
        let line = output.split(separator: "\n").first.map(String.init) ?? output
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }
}
