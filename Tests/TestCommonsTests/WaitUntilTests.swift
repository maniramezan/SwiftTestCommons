import Foundation
import Testing
import TestCommons

struct WaitUntilTests {
    @Test func timeoutIncludesLastObservation() async {
        do {
            _ = try await waitUntil(timeout: .zero, operation: { 42 }, matching: { $0 == 0 })
            Issue.record("Expected timeout")
        } catch let error as ObservationTimeout<Int> {
            #expect(error.lastObservation == 42)
        } catch { Issue.record(error) }
    }

    @MainActor
    private final class Model {
        var count = 0
    }

    @MainActor
    @Test func closuresCanReadNonSendableStateInTheCallersIsolation() async throws {
        let model = Model()
        Task { @MainActor in model.count = 3 }
        let count = try await waitUntil(timeout: .seconds(5), pollInterval: .milliseconds(1)) {
            model.count
        } matching: {
            $0 == 3
        }
        #expect(count == 3)
    }
}
