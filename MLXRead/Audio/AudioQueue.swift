import Foundation

/// Bounded in-flight counter used by `StreamingAudioPlayer` to keep the
/// number of scheduled-but-unplayed buffers small (backpressure for the
/// synthesis producer) and to await drain at end of a session.
///
/// `epoch` guards against stale completion callbacks from a previous session
/// decrementing the counter of a newer one.
actor AudioQueue {
    private let capacity: Int
    private(set) var inFlight = 0
    private(set) var epoch: UInt64 = 0

    private var spaceWaiters: [CheckedContinuation<Void, Never>] = []
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    /// Suspends until there is room for another in-flight buffer, then
    /// reserves the slot. Returns the epoch the reservation belongs to.
    func acquire() async -> UInt64 {
        while inFlight >= capacity {
            await withCheckedContinuation { spaceWaiters.append($0) }
        }
        inFlight += 1
        return epoch
    }

    /// Releases a slot reserved in `epoch`. Stale releases are ignored.
    func release(epoch releasedEpoch: UInt64) {
        guard releasedEpoch == epoch, inFlight > 0 else { return }
        inFlight -= 1
        if !spaceWaiters.isEmpty {
            spaceWaiters.removeFirst().resume()
        }
        if inFlight == 0 {
            resumeDrainWaiters()
        }
    }

    /// Suspends until every in-flight buffer has been released or the queue
    /// has been reset.
    func drain() async {
        guard inFlight > 0 else { return }
        await withCheckedContinuation { drainWaiters.append($0) }
    }

    /// Invalidates the current epoch, zeroes the counter, and resumes all
    /// waiters. Used on immediate stop.
    func reset() {
        epoch &+= 1
        inFlight = 0
        let space = spaceWaiters
        spaceWaiters = []
        space.forEach { $0.resume() }
        resumeDrainWaiters()
    }

    private func resumeDrainWaiters() {
        let waiters = drainWaiters
        drainWaiters = []
        waiters.forEach { $0.resume() }
    }
}
