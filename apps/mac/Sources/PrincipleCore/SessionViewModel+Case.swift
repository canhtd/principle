import Foundation

extension SessionViewModel {
    /// Files the answer's `case` into `memory/cases/` — the write the engine
    /// used to spend a `Write` call on, and sometimes skipped (``CaseSummary``).
    ///
    /// One consult is one case file: the first answer that carries a case
    /// creates it and records where it went on the session, and every later turn
    /// appends to that same file. An answer with no `case` in its trailer files
    /// nothing, exactly as an answer with no `principles` draws no cards (AE2).
    ///
    /// Nothing in here may cost the answer. It has already been persisted by the
    /// time this runs, so a failure becomes a message on screen and the
    /// transcript is untouched.
    func fileCase(_ answer: ParsedAnswer, in session: ChatSession) {
        guard let summary = answer.caseSummary else { return }
        do {
            if let path = session.caseFilePath, !path.isEmpty {
                try caseFiles.appendUpdate(summary, toCaseAt: path)
                return
            }
            let filed = try caseFiles.create(
                summary,
                diagnosis: answer.diagnosis,
                principles: answer.principles,
                corpus: corpus
            )
            var updated = session
            updated.caseFilePath = filed.relativePath
            try store.save(updated)
            apply(updated)
            if let indexFailure = filed.indexFailure {
                errorMessage = indexFailure
            }
        } catch {
            errorMessage = "Could not write the case file: \(error.localizedDescription)"
            Self.logger.error("Filing the case failed: \(String(describing: error), privacy: .public)")
        }
    }
}
