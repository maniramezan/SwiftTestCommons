# Faking dependencies and time

Script dependency results, stub HTTP traffic per session, and control time without sleeping.

## Overview

### Script a dependency

``ScriptedResponder`` records every request and answers call *n* with outcome *n*.
Forward an injected closure or protocol method to ``ScriptedResponder/respond(to:)``.

```swift
import Testing
import TestCommons

@Test func scriptedFetchFailsThenSucceeds() async throws {
    let responder = ScriptedResponder<String, Int>([.failure(TestError()), .success(42)])
    let fetch: @Sendable (String) async throws -> Int = { try await responder.respond(to: $0) }

    await #expect(throws: TestError()) { try await fetch("item") }
    let value = try await fetch("item")
    #expect(value == 42)
    #expect(await responder.requests == ["item", "item"])
}
```

This example checks the scripted failure and success explicitly. To test a consumer's
retry policy, inject `fetch` into that consumer and call its retrying operation. Retry
only errors the policy considers transient, and propagate cancellation and unexpected errors.

A call after the script is used throws ``ScriptedResponder/Exhausted`` unless you pass a
`fallback`. That error is distinct from anything you script, so an unexpected extra call
cannot pass a test that expects a scripted failure.

To observe in-flight state, hold a specific call before it arrives:

```swift
import Testing
import TestCommons

@Test func checkInFlightState() async throws {
    let responder = ScriptedResponder<Int, String>([.success("done")])
    let gate = await responder.hold(call: 0)
    async let call = responder.respond(to: 1)

    _ = try await responder.waitForCalls(1)
    // Assert loading state here; the call is recorded but not answered.
    gate.open()
    let result = try await call
    #expect(result == "done")
}
```

### Stub HTTP responses

``StubbedURLSession`` creates a `URLSession` whose requests are answered in process.
Each instance routes only its own requests, so parallel tests do not share responses.

```swift
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Testing
import TestCommons

@Test func checkStatusHandling() async throws {
    let stub = try StubbedURLSession(responses: [.text("busy", statusCode: 503), .json(#"{"ok":true}"#)])
    defer { stub.invalidate() }

    let url = try #require(URL(string: "https://example.test/status"))
    let (_, first) = try await stub.session.data(from: url)
    #expect((first as? HTTPURLResponse)?.statusCode == 503)
    let (body, _) = try await stub.session.data(from: url)
    #expect(String(decoding: body, as: UTF8.self) == #"{"ok":true}"#)
    #expect(stub.requests.count == 2)
}
```

Use ``StubbedURLSession/init(configuration:handler:)`` to choose a response from the
request, or throw a `URLError` to simulate a transport failure. Recorded requests keep
per-request headers and expose request bodies through `httpBody`. On Linux, set headers and
`httpBody` on the request itself; FoundationNetworking hides session headers and upload-task bodies. Each stub occupies one
of ``StubbedURLSession/maximumConcurrentSessions`` routes until session invalidation finishes. Keep the stub alive while
the session is in use; unrouted requests fail rather than reaching the network.

### Control time

Inject ``ManualClock`` where code accepts `some Clock<Duration>`. Sleeps resume only
when the test advances time, so debounce and retry tests run instantly and deterministically.

```swift
import Testing
import TestCommons

@Test func checkDelayedWork() async throws {
    let clock = ManualClock()
    async let work: String = {
        try await clock.sleep(for: .seconds(30))
        return "fired"
    }()

    try await clock.waitForSleepers(1)
    clock.advance(by: .seconds(30))
    let result = try await work
    #expect(result == "fired")
}
```

Wait for the sleep to register with ``ManualClock/waitForSleepers(_:timeout:)`` before
advancing: advancing first does not wake a sleep that starts later. Cancelling a
sleeping task removes only that sleeper.

The `async let` child tasks are cancelled and awaited when their scope exits, including
when an observation times out or the test is cancelled.
