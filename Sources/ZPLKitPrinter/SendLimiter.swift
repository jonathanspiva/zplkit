import Synchronization

/// Caps how many `ZPLPrinter.send()` calls may run their blocking socket work
/// at once, process-wide.
///
/// `send()` blocks a GCD thread for its whole connect + write, up to the full
/// timeout against an unreachable printer. Without a cap, a mass fan-out (60+
/// concurrent sends) can exhaust GCD's thread pool and starve every other
/// `send()` as well as unrelated global-queue work. Callers beyond the limit
/// wait here, without holding a thread, until a slot frees up.
///
/// Waiting is cancellation-aware: a task cancelled while queued throws
/// `CancellationError` and gives up its place in line. Slots are handed to
/// waiters in FIFO order.
final class SendLimiter: Sendable {
    /// The limiter every `ZPLPrinter.send()` goes through.
    static let shared = SendLimiter(limit: ZPLPrinter.maxConcurrentSends)

    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private struct State {
        var available: Int
        var nextID: UInt64 = 0
        var waiters: [Waiter] = []
    }

    /// The maximum number of slots held at once.
    let limit: Int

    private let state: Mutex<State>

    init(limit: Int) {
        precondition(limit > 0, "SendLimiter needs at least one slot")
        self.limit = limit
        self.state = Mutex(State(available: limit))
    }

    /// Number of slots currently held. For tests and diagnostics.
    var inUse: Int {
        state.withLock { limit - $0.available }
    }

    /// Number of callers waiting for a slot. For tests.
    var queuedForTesting: Int {
        state.withLock { $0.waiters.count }
    }

    /// Waits for a slot. Every successful `acquire()` must be paired with
    /// exactly one `release()`.
    ///
    /// - Throws: `CancellationError` if the task is cancelled before a slot is
    ///   granted. No slot is held in that case.
    func acquire() async throws {
        let id = state.withLock { s in
            s.nextID += 1
            return s.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Checking cancellation under the lock closes the race with
                // onCancel: either it runs first (and this sees the flag) or
                // this registers first (and onCancel finds the waiter).
                let immediate: Result<Void, Error>? = state.withLock { s in
                    if Task.isCancelled { return .failure(CancellationError()) }
                    if s.available > 0 {
                        s.available -= 1
                        return .success(())
                    }
                    s.waiters.append(Waiter(id: id, continuation: continuation))
                    return nil
                }
                if let immediate { continuation.resume(with: immediate) }
            }
        } onCancel: {
            let waiter = state.withLock { s -> Waiter? in
                guard let index = s.waiters.firstIndex(where: { $0.id == id }) else { return nil }
                return s.waiters.remove(at: index)
            }
            waiter?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Returns a slot, handing it straight to the longest waiter if there is
    /// one.
    func release() {
        let next = state.withLock { s -> Waiter? in
            if s.waiters.isEmpty {
                s.available += 1
                precondition(s.available <= limit, "SendLimiter released more slots than it granted")
                return nil
            }
            return s.waiters.removeFirst()
        }
        next?.continuation.resume()
    }
}
