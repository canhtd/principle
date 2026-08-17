import Foundation
import os

/// What one filed case left behind.
public struct FiledCase: Equatable, Sendable {
    /// The case file's path relative to the repo root, e.g.
    /// `memory/cases/2026-08-15-bo-thuoc-la.md`. Persisted on the session so
    /// every later turn of the same consult updates this same file.
    public let relativePath: String
    /// Set when the case file landed but the index line did not. The case is
    /// still filed, so this is a message to show, not a reason to retry.
    public let indexFailure: String?

    public init(relativePath: String, indexFailure: String? = nil) {
        self.relativePath = relativePath
        self.indexFailure = indexFailure
    }
}

/// Writes `memory/cases/` and the index in `memory/MEMORY.md` — the half of the
/// memory loop the engine used to do with `Write` and `Edit`.
///
/// Moving it into the app was measured, not stylistic: composing the file cost
/// about 29 s of one turn before a single character of the answer could arrive,
/// and a small model sometimes answered without writing it at all. The engine
/// now dictates the case in the trailer it was already emitting (``CaseSummary``)
/// and this store does the filing.
///
/// One consult is one case file. The first turn creates it; every later turn
/// appends a `## Cập nhật` section to the same file and adds no second index
/// line. The repo path is injected, never hardcoded.
public struct CaseFileStore: Sendable {
    /// Where cases live, relative to the repo root.
    public static let relativeDirectory = "memory/cases"
    /// The template the repo's memory protocol documents itself with.
    public static let templateFileName = "_TEMPLATE.md"

    public let repoURL: URL
    private let calendar: Calendar

    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "CaseFileStore")

    public init(repoURL: URL, calendar: Calendar = .current) {
        self.repoURL = repoURL
        self.calendar = calendar
    }

    public var directoryURL: URL { Self.url(repoURL, Self.relativeDirectory) }
    public var indexURL: URL { Self.url(repoURL, ProfileStore.relativePath) }

    // MARK: - The first turn of a consult

    /// Writes the case file and appends one index line. Returns where the file
    /// landed so the session can find it again on the next turn.
    @discardableResult
    public func create(
        _ summary: CaseSummary,
        diagnosis: Diagnosis? = nil,
        principles: [PrincipleRef] = [],
        corpus: CorpusStore = CorpusStore(records: []),
        date: Date = Date()
    ) throws -> FiledCase {
        let day = CaseDocument.day(date, calendar: calendar)
        let fileName = availableFileName(day: day, slug: summary.fileSlug)
        let text = CaseDocument.render(
            summary: summary,
            diagnosis: diagnosis,
            principleLines: CaseDocument.principleLines(principles, corpus: corpus),
            headings: CaseDocument.headings(fromTemplate: template()),
            date: date,
            calendar: calendar
        )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)

        let relativePath = "\(Self.relativeDirectory)/\(fileName)"
        do {
            try appendIndexLine(day: day, fileName: fileName, summary: summary, diagnosis: diagnosis)
        } catch {
            // The case itself is on disk; losing the index line must not read as
            // "nothing was written", or the next turn files the case twice.
            Self.logger.error("Case filed but the index was not updated: \(String(describing: error), privacy: .public)")
            return FiledCase(
                relativePath: relativePath,
                indexFailure: "Filed \(relativePath), but could not update the index in "
                    + "\(ProfileStore.relativePath): \(error.localizedDescription)"
            )
        }
        return FiledCase(relativePath: relativePath)
    }

    // MARK: - Every later turn

    /// Appends what this turn changed to the case the consult already opened.
    /// Never a second file, never a second index line.
    public func appendUpdate(_ summary: CaseSummary, toCaseAt relativePath: String, date: Date = Date()) throws {
        let block = CaseDocument.updateSection(summary: summary, date: date, calendar: calendar)
        guard !block.isEmpty else { return }
        let url = Self.url(repoURL, relativePath)
        guard let existing = try? String(contentsOf: url, encoding: .utf8) else {
            throw CaseFileStoreError.caseFileMissing(url)
        }
        let separator = existing.hasSuffix("\n") ? "\n" : "\n\n"
        try Data((existing + separator + block).utf8).write(to: url, options: .atomic)
    }

    // MARK: - Pieces

    /// `YYYY-MM-DD-<slug>.md`, suffixed until it is a name no file has: two
    /// consults on the same subject on the same day must not overwrite one
    /// another.
    private func availableFileName(day: String, slug: String) -> String {
        let stem = "\(day)-\(slug)"
        var candidate = "\(stem).md"
        var suffix = 2
        while FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(candidate).path) {
            candidate = "\(stem)-\(suffix).md"
            suffix += 1
        }
        return candidate
    }

    private func template() -> String? {
        try? String(contentsOf: directoryURL.appendingPathComponent(Self.templateFileName), encoding: .utf8)
    }

    /// Reads MEMORY.md, inserts one line, writes it back atomically. A file that
    /// exists but cannot be read throws rather than being replaced — the profile
    /// a terminal session hand-edits lives in there too.
    private func appendIndexLine(
        day: String,
        fileName: String,
        summary: CaseSummary,
        diagnosis: Diagnosis?
    ) throws {
        let existing: String
        if FileManager.default.fileExists(atPath: indexURL.path) {
            guard let text = try? String(contentsOf: indexURL, encoding: .utf8) else {
                throw ProfileStoreError.unreadable(indexURL)
            }
            existing = text
        } else {
            existing = "\(ProfileStore.defaultTitle)\n"
        }
        let line = CaseIndex.line(
            day: day,
            slug: summary.fileSlug,
            fileName: fileName,
            kind: diagnosis?.kind ?? "",
            direction: summary.direction,
            followUp: summary.followUp
        )
        try FileManager.default.createDirectory(
            at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(CaseIndex.appending(line, to: existing).utf8).write(to: indexURL, options: .atomic)
    }

    private static func url(_ repoURL: URL, _ relativePath: String) -> URL {
        relativePath.split(separator: "/").reduce(repoURL) { $0.appendingPathComponent(String($1)) }
    }
}

/// The one failure the caller has to tell apart: the consult remembers a case
/// file that is no longer there, so there is nothing to append this turn to.
public enum CaseFileStoreError: LocalizedError, Equatable {
    case caseFileMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .caseFileMissing(let url):
            "The case file \(url.path) is gone, so this turn could not be added to it."
        }
    }
}
