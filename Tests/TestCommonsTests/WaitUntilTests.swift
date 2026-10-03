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
}
