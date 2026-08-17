import Foundation

@testable import PrincipleCore

/// An availability check the test can park mid-flight, so a second Gửi / Gửi lại
/// can arrive while the first one is still inside `ensureEngineAvailable()` —
/// the exact window a double tap lands in.
final class GatedAvailabilityProvider: EngineAvailabilityProviding, @unchecked Sendable {
    private let value: EngineAvailability
    private let lock = NSLock()
    private var isOpen: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var callCount = 0

    init(value: EngineAvailability, open: Bool = true) {
        self.value = value
        isOpen = open
    }

    /// How many checks have started — including the one currently parked.
    var calls: Int { lock.withLock { callCount } }

    func currentAvailability() async -> EngineAvailability {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let passThrough: Bool = lock.withLock {
                callCount += 1
                if isOpen { return true }
                waiters.append(continuation)
                return false
            }
            if passThrough { continuation.resume() }
        }
        return value
    }

    /// The next check parks instead of answering.
    func close() { lock.withLock { isOpen = false } }

    /// Lets everyone waiting through, and everyone arriving after them.
    func open() {
        let parked: [CheckedContinuation<Void, Never>] = lock.withLock {
            isOpen = true
            let waiting = waiters
            waiters = []
            return waiting
        }
        parked.forEach { $0.resume() }
    }
}
