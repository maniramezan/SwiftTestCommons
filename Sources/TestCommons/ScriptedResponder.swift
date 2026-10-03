/// A scripted fake that records each request and answers with the next scripted outcome.
///
/// Use it to implement an injected dependency: forward each call to ``respond(to:)``.
/// Calls are numbered from zero in arrival order, and call *n* always receives
/// outcome *n*, even when an earlier call is held and finishes later. ``hold(call:)`` returns a gate that
/// suspends a specific call after it is recorded and before it is answered, so a test
/// can observe in-flight state deterministically.
///
/// ```swift
/// let responder = ScriptedResponder<String, Int>([.success(1), .failure(TestError())])
/// let fetch: @Sendable (String) async throws -> Int = { try await responder.respond(to: $0) }
/// ```
///
/// ## Topics
///
/// ### Creating a responder
/// - ``init(_:fallback:)``
/// - ``Exhausted``
///
/// ### Answering calls
/// - ``respond(to:)``
/// - ``hold(call:)``
///
/// ### Inspecting calls
/// - ``requests``
/// - ``callCount``
/// - ``waitForCalls(_:timeout:)``
public actor ScriptedResponder<Request: Sendable, Response: Sendable> {
    /// Thrown when a call arrives after every scripted outcome is used and no fallback exists.
    ///
    /// Distinct from errors you script, so exhaustion cannot be mistaken for an expected failure.
    ///
    /// ## Topics
    /// - ``callIndex``
    public struct Exhausted: Error, Equatable {
        /// The zero-based index of the call that found the script empty.
        public let callIndex: Int
    }

    private let outcomes: [Result<Response, any Error>]
    private let fallback: Result<Response, any Error>?
    private var gates: [Int: AsyncGate] = [:]

    /// The recorded requests in arrival order, including calls still held or in flight.
    public private(set) var requests: [Request] = []

    /// The number of calls received.
    public var callCount: Int { requests.count }

    /// Creates a responder that answers calls with `outcomes` in order.
    /// - Parameters:
    ///   - outcomes: Successes and failures, indexed by call number.
    ///   - fallback: The outcome for calls after the script is used; `nil` throws ``Exhausted``.
    public init(_ outcomes: [Result<Response, any Error>], fallback: Result<Response, any Error>? = nil) {
        self.outcomes = outcomes
        self.fallback = fallback
    }

    /// Returns a gate that holds the call with the given zero-based index until opened.
    ///
    /// Register the hold before the call arrives. The call is recorded before it waits,
    /// and cancelling the calling task while held throws `CancellationError`.
    /// - Parameter call: The zero-based call index to hold.
    /// - Returns: The gate to open when the call may proceed.
    public func hold(call: Int) -> AsyncGate {
        precondition(call >= 0)
        if let gate = gates[call] { return gate }
        let gate = AsyncGate()
        gates[call] = gate
        return gate
    }

    /// Records `request` and answers it with the next scripted outcome.
    /// - Parameter request: The request made to the faked dependency.
    /// - Returns: The scripted response.
    /// - Throws: A scripted failure, ``Exhausted``, or cancellation while held.
    public func respond(to request: Request) async throws -> Response {
        let index = requests.count
        requests.append(request)
        if let gate = gates[index] {
            try await gate.wait()
        }
        if index < outcomes.count {
            return try outcomes[index].get()
        }
        guard let fallback else {
            throw Exhausted(callIndex: index)
        }
        return try fallback.get()
    }

    /// Waits in real time until at least `count` calls have been recorded.
    /// - Parameters:
    ///   - count: The nonnegative minimum number of calls.
    ///   - timeout: The real-time observation budget.
    /// - Returns: A snapshot of the recorded requests.
    /// - Throws: ``ObservationTimeout`` with the last snapshot, or cancellation.
    public func waitForCalls(_ count: Int, timeout: Duration = .seconds(2)) async throws -> [Request] {
        precondition(count >= 0)
        return try await waitUntil(
            timeout: timeout, pollInterval: .milliseconds(1),
            operation: { await self.requests }, matching: { $0.count >= count })
    }
}
