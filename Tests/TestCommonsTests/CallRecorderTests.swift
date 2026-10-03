import Foundation
import Testing
import TestCommons

struct CallRecorderTests {
    @Test
    func recorderPreservesOrderAndSnapshots() async {
        let recorder = CallRecorder<String>()
        #expect(await recorder.values() == [])
        #expect(await recorder.lastValue() == nil)
        await recorder.record("first")
        let snapshot = await recorder.values()
        await recorder.record("second")
        #expect(snapshot == ["first"])
        #expect(await recorder.values() == ["first", "second"])
        #expect(await recorder.lastValue() == "second")
    }

    @Test
    func recorderRetainsEveryConcurrentCall() async {
        let recorder = CallRecorder<Int>()
        await withTaskGroup(of: Void.self) { group in
            for value in 0..<100 {
                group.addTask { await recorder.record(value) }
            }
        }
        let values = await recorder.values()
        #expect(values.count == 100)
        #expect(values.sorted() == Array(0..<100))
    }

    @Test func recorderWaitsAndResets() async throws {
        let recorder = CallRecorder<Int>()
        let waiting = Task { try await recorder.waitForCount(2, timeout: .seconds(2)) }
        await recorder.record(1)
        await recorder.record(2)
        #expect(try await waiting.value == [1, 2])
        await recorder.reset()
        #expect(await recorder.count == 0)
    }
}
