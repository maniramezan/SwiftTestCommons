import Testing
import TestCommons

struct ObservationTimeoutTests {
    @Test func descriptionIncludesLastObservation() async {
        let timeout = await #expect(throws: ObservationTimeout<[String]>.self) {
            try await waitUntil(timeout: .zero, operation: { ["pending"] }, matching: { $0.isEmpty })
        }
        #expect(timeout?.description == #"Condition did not match before the deadline; last observation: ["pending"]"#)
    }
}
