import Foundation

extension SessionViewModel {
    /// What one turn produced, assembled as the stream arrives.
    struct TurnOutcome {
        /// The engine's own session id, for `--resume` next time (KTD2).
        var engineSessionID: String?
        /// The terminal `result` text. Absent when the turn failed or was stopped.
        var finalText: String?
    }

    // MARK: - Sending

    /// Asks the current session a question: persists it, then runs the turn.
    public func send(_ text: String) async {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !phase.isStreaming, let sessionID = selectedSessionID else { return }
        // Claim the turn before the first suspension point: the availability
        // check below is an await, and with the phase still `.idle` a second
        // tap on Send passed this same guard and spawned a duplicate turn.
        phase = .preparing
        guard await ensureEngineAvailable() else {
            phase = .idle
            return
        }

        errorMessage = nil
        lastPrompt = prompt
        // Cleared only once the turn is really going, so a blocked engine hands
        // the question back instead of eating it.
        draft = ""
        do {
            let session = try store.appendMessage(ChatMessage(role: .user, text: prompt), to: sessionID)
            apply(session)
            await runTurn(prompt: prompt, session: session)
        } catch {
            // Claimed above but never reached `runTurn`, which is what would
            // otherwise hand the phase back.
            phase = .idle
            errorMessage = "Could not save the question to the session: \(error.localizedDescription)"
            Self.logger.error("Persisting the question failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Runs the last question again after a failure. The question is already in
    /// the transcript, so it is not appended a second time.
    public func resend() async {
        guard canResend, let prompt = lastPrompt, let sessionID = selectedSessionID else { return }
        // Same claim as `send`: `canResend` reads the phase, so it has to stop
        // being `.idle` before the await, not after it.
        phase = .preparing
        guard await ensureEngineAvailable() else {
            phase = .idle
            return
        }
        do {
            await runTurn(prompt: prompt, session: try store.load(id: sessionID))
        } catch {
            phase = .idle
            errorMessage = "Could not reopen the session: \(error.localizedDescription)"
        }
    }

    /// KTD4: the check runs again right before every turn, not just at launch.
    /// A blocked engine leaves the reason on screen instead of a dead spawn — and
    /// that includes a repo with no `ask-ray` skill in it, which the engine would
    /// otherwise answer with `Unknown command: /ask-ray`.
    private func ensureEngineAvailable() async -> Bool {
        await refreshAvailability()
        guard isEngineBlocked else { return true }
        errorMessage = engineGuidance
        return false
    }

    /// Stops the turn in flight. The stream ends normally, so whatever already
    /// arrived is kept.
    public func stop() {
        guard phase.isStreaming else { return }
        engine.cancel()
    }

    // MARK: - One turn

    private func runTurn(prompt: String, session: ChatSession, allowSeededRetry: Bool = true) async {
        errorMessage = nil
        activeSessionID = session.id
        phase = .preparing
        streamingText = ""

        let resumeID = session.nextTurnStart.resumeID
        // Read only if this turn opens an engine session; a `--resume` turn never
        // asks for it (`ConsultPrompt.text`).
        let outgoing = ConsultPrompt.text(for: session, question: prompt) {
            RepoContext.read(at: store.repoURL)
        }

        var outcome = TurnOutcome()
        do {
            let stream = engine.send(
                prompt: outgoing,
                model: session.model,
                resumeID: resumeID,
                cwd: store.repoURL,
                extraArgs: ConsultPrompt.systemPromptArguments(voice: voice)
            )
            for try await event in stream {
                apply(event, to: &outcome)
            }
        } catch {
            // KTD2: the engine lost the context we asked it to resume. Drop the
            // dead id and run the turn once more as a fresh session seeded from
            // the transcript the app owns. Only once — a second failure is real.
            if allowSeededRetry, resumeID != nil, TurnFailure.indicatesDeadSession(error) {
                Self.logger.notice("Engine lost session \(resumeID ?? "", privacy: .public); retrying seeded")
                await runTurn(prompt: prompt, session: clearDeadSession(session), allowSeededRetry: false)
                return
            }
            finish(outcome, error: error)
            return
        }
        finish(outcome, error: nil)
    }

    /// Maps one event onto the progress line (KTD7) and collects the answer.
    private func apply(_ event: StreamEvent, to outcome: inout TurnOutcome) {
        // Anything under a `parent_tool_use_id` is a lookup, not the answer.
        if event.isInSubagent {
            phase = .subagent
            return
        }
        switch event {
        case .sessionStarted(let start):
            outcome.engineSessionID = start.sessionID
            phase = .preparing
        case .thinking, .thinkingTokens:
            phase = .thinking
        case .toolUse(let use):
            phase = .runningTool(ToolProgress.describe(use))
        case .toolResult:
            break
        case .textBlockStarted, .textDelta, .thinkingDelta:
            // `PartialMessageFilter` rewrites these into `.text` / `.thinking`
            // inside the run, so the view model sees one vocabulary whether or not
            // partials were asked for. Appending here too would double the answer.
            break
        case .text(let text, _):
            streamingText += text
            phase = .answering
        case .result(let result):
            outcome.engineSessionID = result.sessionID
            // A failed run reports its error message in the same field; that is
            // an error to show, never an answer to file away.
            if !result.isError { outcome.finalText = result.text }
        }
    }

    private func finish(_ outcome: TurnOutcome, error: (any Error)?) {
        let sessionID = activeSessionID
        // On a stop or a failure, whatever streamed is still worth keeping.
        let raw = (outcome.finalText ?? streamingText).trimmingCharacters(in: .whitespacesAndNewlines)
        // KTD3: the trailer is how the engine cites principles to the app. It is
        // split off here so the transcript stores clean prose plus the diagnosis
        // and the per-principle bridge, and reopening the session re-renders the
        // cards without another turn.
        let answer = TrailerParser.parse(raw)
        phase = .idle
        activeSessionID = nil
        streamingText = ""
        if let error {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            Self.logger.error("Turn failed: \(String(describing: error), privacy: .public)")
        }

        guard let sessionID else { return }
        do {
            if answer.text.isEmpty, answer.principles.isEmpty, answer.diagnosis == nil {
                // Nothing to file, but the engine's id still buys a `--resume`.
                if let engineSessionID = outcome.engineSessionID {
                    var session = try store.load(id: sessionID)
                    session.claudeSessionID = engineSessionID
                    try store.save(session)
                    apply(session)
                }
            } else {
                apply(
                    try store.appendMessage(
                        ChatMessage(
                            role: .assistant,
                            text: answer.text,
                            diagnosis: answer.diagnosis,
                            principles: answer.principles
                        ),
                        to: sessionID,
                        claudeSessionID: outcome.engineSessionID
                    )
                )
            }
        } catch {
            errorMessage = "Could not save the answer: \(error.localizedDescription)"
            Self.logger.error("Persisting the answer failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func clearDeadSession(_ session: ChatSession) -> ChatSession {
        do {
            let cleared = try store.clearClaudeSessionID(for: session.id)
            apply(cleared)
            return cleared
        } catch {
            // The file is unwritable; still retry seeded rather than give up.
            Self.logger.error("Clearing the dead session id failed: \(String(describing: error), privacy: .public)")
            var cleared = session
            cleared.claudeSessionID = nil
            return cleared
        }
    }
}
