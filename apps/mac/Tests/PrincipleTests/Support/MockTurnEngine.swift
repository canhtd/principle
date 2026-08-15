import Foundation

@testable import PrincipleCore

/// Stands in for `EngineService` so a turn can be driven event by event without
/// spawning anything. Two modes: `.script` replays a canned turn, `.live` hands
/// the continuation to the test so it can interleave assertions between events.
final class MockTurnEngine: TurnRunning, @unchecked Sendable {
    struct Call: Equatable {
        let prompt: String
        let model: String
        let resumeID: String?
    }

    enum Response {
        case script(events: [StreamEvent], failure: Error? = nil)
        case live
    }

    private let lock = NSLock()
    private var recordedCalls: [Call] = []
    private var recordedCancels = 0
    private var pendingResponses: [Response]
    private var liveContinuation: AsyncThrowingStream<StreamEvent, Error>.Continuation?

    init(responses: [Response] = [.live]) {
        pendingResponses = responses
    }

    var calls: [Call] { lock.withLock { recordedCalls } }
    var cancelCount: Int { lock.withLock { recordedCancels } }
    var hasLiveStream: Bool { lock.withLock { liveContinuation != nil } }

    // MARK: - TurnRunning

    func send(
        prompt: String,
        model: String,
        resumeID: String?,
        cwd: URL,
        extraArgs: [String]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let response: Response = lock.withLock {
            recordedCalls.append(Call(prompt: prompt, model: model, resumeID: resumeID))
            return pendingResponses.isEmpty ? .live : pendingResponses.removeFirst()
        }
        return AsyncThrowingStream { continuation in
            switch response {
            case .script(let events, let failure):
                events.forEach { continuation.yield($0) }
                continuation.finish(throwing: failure)
            case .live:
                lock.withLock { liveContinuation = continuation }
            }
        }
    }

    /// Matches `EngineService.cancel()`: the stream ends normally, so whatever
    /// already streamed stays in the transcript.
    func cancel() {
        let live: AsyncThrowingStream<StreamEvent, Error>.Continuation? = lock.withLock {
            recordedCancels += 1
            return liveContinuation
        }
        live?.finish()
    }

    // MARK: - Driving a live turn

    func emit(_ event: StreamEvent) {
        lock.withLock { liveContinuation }?.yield(event)
    }

    func finish(throwing error: Error? = nil) {
        lock.withLock { liveContinuation }?.finish(throwing: error)
    }
}

/// Availability without probing a binary.
struct StubAvailabilityProvider: EngineAvailabilityProviding {
    let value: EngineAvailability

    func currentAvailability() async -> EngineAvailability { value }
}

/// Polls a main-actor condition, yielding so the view model's stream loop runs.
@MainActor
func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
    return condition()
}
