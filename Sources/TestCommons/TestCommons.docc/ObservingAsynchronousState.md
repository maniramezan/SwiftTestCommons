# Observing asynchronous state

Wait for state, streams, and suspended work with deadlines instead of fixed sleeps.

## Overview

### Wait for a condition

``waitUntil(timeout:pollInterval:isolation:operation:matching:)`` reads state until a
predicate accepts it, using a monotonic deadline. On timeout it throws
``ObservationTimeout``, whose ``ObservationTimeout/lastObservation`` shows what the state was.
The closures run in the caller's isolation, so a main-actor test can read a main-actor model.

```swift
import Testing
import TestCommons

@MainActor
final class Counter {
    var value = 0
}

@MainActor
@Test func counterReachesThree() async throws {
    let counter = Counter()
    Task { @MainActor in counter.value = 3 }
    let value = try await waitUntil(timeout: .seconds(2)) {
        counter.value
    } matching: {
        $0 == 3
    }
    #expect(value == 3)
}
```

The operation must return promptly: the deadline is checked between observations and
cannot interrupt a closure that never returns. One observation is made even for a zero
timeout. Prefer the count waits on ``CallRecorder``, ``ScriptedResponder``,
``StubbedURLSession``, and ``ManualClock`` when they fit; those wake on each change instead
of polling.

### Observe a stream

``observeStream(_:maxCount:timeout:until:)`` collects events from any sendable
`AsyncSequence` with both an event budget and a time budget, and reports why it stopped.

```swift
import Testing
import TestCommons

@Test func streamDeliversReady() async throws {
    let (stream, continuation) = AsyncStream.makeStream(of: String.self)
    continuation.yield("loading")
    continuation.yield("ready")

    let observation = try await observeStream(stream, maxCount: 10, timeout: .seconds(2)) { $0 == "ready" }
    #expect(observation.values == ["loading", "ready"])
    #expect(observation.end == .matched)
}
```

A timeout cancels iteration, which finishes an `AsyncStream` permanently. Observations that
stop by matching or reaching the limit leave the stream usable.

### Hold work at a known point

``AsyncGate`` is a one-shot signal. Code under test, or a fake it calls, awaits the gate;
the test checks ``AsyncGate/waiterCount`` to know the work has suspended, asserts the
in-between state, then opens the gate.

```swift
import Testing
import TestCommons

@Test func workWaitsForTheGate() async throws {
    let gate = AsyncGate()
    let finished = TestValueBox(false)
    let work = Task {
        try await gate.wait()
        finished.set(true)
    }

    _ = try await waitUntil(timeout: .seconds(2)) { gate.waiterCount } matching: { $0 == 1 }
    #expect(finished.get() == false)
    gate.open()
    try await work.value
    #expect(finished.get())
}
```

Cancelling a waiting task removes only that waiter and throws `CancellationError`.
