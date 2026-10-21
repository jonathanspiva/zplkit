import Foundation
import Testing
@testable import ZPLKitPrinter

/// `SendLimiter` in isolation: slot accounting, FIFO hand-off, and
/// cancellation while queued.
@Suite("Send Limiter Tests")
struct SendLimiterTests {

    @Test("acquire() grants up to the limit without waiting")
    func grantsUpToLimit() async throws {
        let limiter = SendLimiter(limit: 3)
        for _ in 0..<3 { try await limiter.acquire() }
        #expect(limiter.inUse == 3)
        for _ in 0..<3 { limiter.release() }
        #expect(limiter.inUse == 0)
    }

    @Test("A waiter beyond the limit proceeds only after a release")
    func waiterProceedsAfterRelease() async throws {
        let limiter = SendLimiter(limit: 1)
        try await limiter.acquire()

        let acquired = Flag()
        let waiter = Task {
            try await limiter.acquire()
            acquired.set()
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!acquired.value, "second acquire() must wait while the only slot is held")

        limiter.release()
        try await waiter.value
        #expect(acquired.value)
        // The slot was handed straight to the waiter, not returned to the pool.
        #expect(limiter.inUse == 1)
        limiter.release()
        #expect(limiter.inUse == 0)
    }

    @Test("Slots are handed to waiters in FIFO order")
    func fifoOrder() async throws {
        let limiter = SendLimiter(limit: 1)
        try await limiter.acquire()

        let order = OrderLog()
        var waiters: [Task<Void, Error>] = []
        for i in 0..<4 {
            waiters.append(Task {
                try await limiter.acquire()
                order.append(i)
                limiter.release()
            })
            // Let each waiter enqueue before starting the next.
            try await waitUntil { limiter.queuedForTesting == i + 1 }
        }

        limiter.release()
        for waiter in waiters { try await waiter.value }
        #expect(order.values == [0, 1, 2, 3])
        #expect(limiter.inUse == 0)
    }

    @Test("Cancelling a queued acquire() throws CancellationError and holds no slot")
    func cancelWhileQueued() async throws {
        let limiter = SendLimiter(limit: 1)
        try await limiter.acquire()

        let waiter = Task { try await limiter.acquire() }
        try await waitUntil { limiter.queuedForTesting == 1 }
        waiter.cancel()

        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(limiter.queuedForTesting == 0)

        // The cancelled waiter must not have consumed the slot on release.
        limiter.release()
        #expect(limiter.inUse == 0)
    }

    @Test("acquire() on an already-cancelled task throws without taking a slot")
    func alreadyCancelled() async throws {
        let limiter = SendLimiter(limit: 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await limiter.acquire()
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(limiter.inUse == 0)
    }
}

/// `send()` cancellation and the process-wide concurrency cap, against a
/// loopback `FakePrinter` that never reads (so writes genuinely block).
///
/// Serialized because both tests count connections against the shared
/// limiter.
@Suite("Send Cancellation Tests", .serialized)
struct SendCancellationTests {

    /// Comfortably larger than loopback socket buffers, so `write()` blocks
    /// against a printer that never reads.
    private static let blockingPayload = Data(repeating: UInt8(ascii: "A"), count: 32 * 1024 * 1024)

    /// Long enough that a test only passes if cancellation, not the timeout,
    /// ended the send.
    private static let longTimeout: TimeInterval = 30

    @Test("Cancelling a send() blocked mid-write returns promptly with CancellationError")
    func cancelDuringWrite() async throws {
        let fake = try FakePrinter(defaultBehavior: .stall)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: Self.longTimeout)
        let task = Task { try await printer.send(Self.blockingPayload) }

        try await waitUntil { fake.connectionCount == 1 }
        // Give write() time to fill the buffers and block.
        try await Task.sleep(nanoseconds: 200_000_000)

        let start = ContinuousClock.now
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test("At most maxConcurrentSends sends connect at once, and queued sends cancel cleanly")
    func fanOutIsBounded() async throws {
        let fake = try FakePrinter(defaultBehavior: .stall)
        defer { fake.shutdown() }

        let limit = ZPLPrinter.maxConcurrentSends
        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: Self.longTimeout)
        let tasks = (0..<(limit + 4)).map { _ in
            Task { try await printer.send(Self.blockingPayload) }
        }

        try await waitUntil { fake.connectionCount == limit }
        // The extra sends must stay queued, not connect.
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(fake.connectionCount == limit)

        let start = ContinuousClock.now
        for task in tasks { task.cancel() }
        for task in tasks {
            await #expect(throws: CancellationError.self) { try await task.value }
        }
        #expect(ContinuousClock.now - start < .seconds(5))
        // Cancelled queued sends never connected.
        #expect(fake.connectionCount == limit)
    }
}

// MARK: - Helpers

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool { lock.withLock { _value } }
    func set() { lock.withLock { _value = true } }
}

private final class OrderLog: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [Int] = []
    var values: [Int] { lock.withLock { _values } }
    func append(_ v: Int) { lock.withLock { _values.append(v) } }
}

private func waitUntil(
    timeout: TimeInterval = 10,
    _ condition: @Sendable () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if condition() { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(condition(), "condition not met within \(timeout)s")
}
