import Foundation
import Testing

@testable import TestCommons

struct ScriptedResponderTests {
    @Test func answersCallsInOrderAndRecordsRequests() async throws {
        let responder = ScriptedResponder<String, Int>([.success(1), .failure(TestError())])
        #expect(try await responder.respond(to: "a") == 1)
        await #expect(throws: TestError()) { try await responder.respond(to: "b") }
        await #expect(throws: ScriptedResponder<String, Int>.Exhausted(callIndex: 2)) {
            try await responder.respond(to: "c")
        }
        #expect(await responder.requests == ["a", "b", "c"])
        #expect(await responder.callCount == 3)
    }

    @Test func fallbackAnswersAfterTheScript() async throws {
        let responder = ScriptedResponder<Int, String>([], fallback: .success("default"))
        #expect(try await responder.respond(to: 1) == "default")
        #expect(try await responder.respond(to: 2) == "default")
    }

    @Test func aHeldCallKeepsItsOwnOutcome() async throws {
        let responder = ScriptedResponder<String, Int>([.success(0), .success(1)])
        let gate = await responder.hold(call: 0)
        #expect(await responder.hold(call: 0) === gate)
        let first = Task { try await responder.respond(to: "first") }
        _ = try await responder.waitForCalls(1)
        #expect(try await responder.respond(to: "second") == 1)
        gate.open()
        #expect(try await first.value == 0)
        #expect(await responder.requests == ["first", "second"])
    }

    @Test func cancellingAHeldCallThrows() async throws {
        let responder = ScriptedResponder<Int, Int>([.success(0)])
        _ = await responder.hold(call: 0)
        let call = Task { try await responder.respond(to: 7) }
        _ = try await responder.waitForCalls(1)
        call.cancel()
        await #expect(throws: CancellationError.self) { try await call.value }
    }

    @Test func structuredHeldCallIsCancelledWhenObservationThrows() async throws {
        let responder = ScriptedResponder<Int, Int>([.success(0)])
        let gate = await responder.hold(call: 0)
        func observe() async throws {
            async let call = responder.respond(to: 7)
            _ = try await responder.waitForCalls(1)
            throw TestError()
        }

        await #expect(throws: TestError()) { try await observe() }
        #expect(gate.waiterCount == 0)
    }

    @Test func waitingForMissingCallsTimesOut() async {
        let responder = ScriptedResponder<Int, Int>([])
        await #expect(throws: ObservationTimeout<[Int]>.self) {
            try await responder.waitForCalls(1, timeout: .milliseconds(10))
        }
    }
}
