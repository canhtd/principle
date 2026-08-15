import Foundation

/// Where a configured repo path stands. Settings warns on anything but `.valid`
/// rather than letting the app fail later with a file error nobody can place.
public enum RepoPathStatus: Equatable, Sendable {
    /// Nothing configured — the built-in location is used.
    case unset
    case valid
    case missing
    case notAFolder
}

/// Everything the Settings window owns, stored in one shared defaults domain (KTD5).
///
/// A value type on purpose: SwiftUI keeps it in `@State` and edits it through
/// bindings — every mutation writes straight through, so `swift run` and the
/// bundled app always read the same three keys — while the library reads those
/// keys through the static accessors, without an instance and off the main actor.
public struct AppSettings: Equatable, Sendable {
    public static let defaultsSuite = PrincipleInfo.bundleIdentifier

    public enum Key {
        public static let responseModel = "responseModel"
        public static let repoPath = "repoPath"
        public static let claudeBinaryOverride = "claudeBinaryOverride"
    }

    /// KTD8: the app maps a display name to a CLI alias for the answering model
    /// and nothing else. Which model a subagent runs on is the skill's business.
    public static let selectableModels = ModelAlias.all

    public let suiteName: String

    /// Passed verbatim as `--model` on the next turn. An alias the app does not
    /// offer is refused rather than handed to the CLI.
    public var responseModel: String {
        didSet {
            guard Self.selectableModels.contains(responseModel) else {
                // Assigning inside `didSet` replaces the value without re-firing it.
                responseModel = oldValue
                return
            }
            write(responseModel, forKey: Key.responseModel)
        }
    }

    /// Raw as typed, empty meaning "use the built-in location".
    public var repoPath: String {
        didSet { write(repoPath, forKey: Key.repoPath) }
    }

    /// Empty means the candidate list; non-empty means exactly this executable (KTD4).
    public var claudeBinaryOverride: String {
        didSet { write(claudeBinaryOverride, forKey: Key.claudeBinaryOverride) }
    }

    public init(suiteName: String = defaultsSuite) {
        let defaults = Self.defaults(suiteName: suiteName)
        self.suiteName = suiteName
        responseModel = Self.responseModel(in: defaults)
        repoPath = Self.repoPath(in: defaults) ?? ""
        claudeBinaryOverride = Self.claudeBinaryOverride(in: defaults) ?? ""
    }

    // MARK: - Reads used by the library

    public static func sharedDefaults() -> UserDefaults? { defaults(suiteName: defaultsSuite) }

    /// `UserDefaults(suiteName:)` refuses the running app's own bundle identifier,
    /// which is exactly what the shipped bundle asks for. Its standard domain *is*
    /// that suite, so both builds still land in the same place.
    static func defaults(suiteName: String) -> UserDefaults? {
        if suiteName == Bundle.main.bundleIdentifier { return .standard }
        return UserDefaults(suiteName: suiteName)
    }

    public static func responseModel(in defaults: UserDefaults?) -> String {
        guard let stored = trimmed(defaults?.string(forKey: Key.responseModel)),
            selectableModels.contains(stored)
        else { return ModelAlias.default }
        return stored
    }

    public static func repoPath(in defaults: UserDefaults?) -> String? {
        trimmed(defaults?.string(forKey: Key.repoPath))
    }

    public static func claudeBinaryOverride(in defaults: UserDefaults?) -> String? {
        trimmed(defaults?.string(forKey: Key.claudeBinaryOverride))
    }

    /// Expands a leading `~` against the process's home directory. Not shell
    /// expansion — a GUI app has no shell to do it.
    public static func expandedURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Repo path

    public var configuredRepoPath: String? { Self.trimmed(repoPath) }

    /// What the stores and the corpus lookup work against.
    public var repoURL: URL {
        guard let configured = configuredRepoPath else { return RepoLocation.current(defaults: nil) }
        return Self.expandedURL(configured)
    }

    public var repoPathStatus: RepoPathStatus {
        guard configuredRepoPath != nil else { return .unset }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: repoURL.path, isDirectory: &isDirectory) else {
            return .missing
        }
        return isDirectory.boolValue ? .valid : .notAFolder
    }

    public var repoPathWarning: String? {
        switch repoPathStatus {
        case .unset, .valid:
            nil
        case .missing:
            "Không tìm thấy thư mục này. Kiểm tra lại đường dẫn — phiên sẽ được ghi vào đây khi anh hỏi câu đầu tiên."
        case .notAFolder:
            "Đường dẫn này là một tệp, không phải thư mục. Chọn thư mục gốc của repo Principle."
        }
    }

    // MARK: - Claude Code binary (KTD4, R5)

    /// `nil` when nothing is configured, which is what the resolver reads as
    /// "use the candidate list".
    public var engineOverridePath: String? { Self.trimmed(claudeBinaryOverride) }

    public func resolvedBinary(candidates: [String] = EngineBinaryResolver.defaultCandidates) -> URL? {
        EngineBinaryResolver.resolve(override: engineOverridePath, candidates: candidates)
    }

    public var binaryOverrideWarning: String? {
        guard let override = engineOverridePath else { return nil }
        // Candidates deliberately empty: this asks about the override alone.
        guard EngineBinaryResolver.resolve(override: override, candidates: []) == nil else { return nil }
        return "Không có tệp thực thi ở đường dẫn này. Để trống để app tự tìm Claude Code."
    }

    public func availabilityProbe(
        checker: EngineAvailabilityChecker = EngineAvailabilityChecker()
    ) -> EngineAvailabilityProbe {
        EngineAvailabilityProbe(checker: checker, overridePath: engineOverridePath)
    }

    // MARK: - Handing the choice to a new session

    /// The sheet opens on the model chosen here, so a change applies to the next
    /// session rather than rewriting the ones already on disk (AE4).
    public func newSessionDraft() -> NewSessionDraft {
        NewSessionDraft(model: responseModel)
    }

    // MARK: - Write-through

    private func write(_ value: String, forKey key: String) {
        let defaults = Self.defaults(suiteName: suiteName)
        // A cleared field is removed, not stored as an empty string, so "unset"
        // stays one state instead of two.
        if let trimmed = Self.trimmed(value) {
            defaults?.set(trimmed, forKey: key)
        } else {
            defaults?.removeObject(forKey: key)
        }
    }
}
