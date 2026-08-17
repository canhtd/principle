import Foundation

@testable import PrincipleCore

/// Journal fixtures for the throwaway repo.
///
/// Every access hands back a *new* store, so a test that writes through one and
/// reads through another is asking the question restart-safety asks: is the
/// answer on disk, or only in memory?
extension TempRepo {
    /// UTC, so a task planned at noon lands on the same day wherever the test runs.
    var journal: JournalStore { JournalStore(repoURL: root, calendar: Self.utcCalendar) }
}
