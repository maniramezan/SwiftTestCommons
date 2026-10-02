import Testing
import TestCommons

struct RecordingTests {
    @Test
    func boxCanReadReplaceAndModify() {
        let box = TestValueBox(["first"])
        #expect(box.get() == ["first"])
        box.set([])
        let count = box.withValue { values in
            values.append("second")
            return values.count
        }
        #expect(count == 1)
        #expect(box.get() == ["second"])
    }

    @Test
    func throwingMutationReleasesLock() {
        let box = TestValueBox(0)
        #expect(throws: TestError()) {
            try box.withValue { value in
                value = 1
                throw TestError()
            }
        }
        // Mutations before an error persist, but subsequent calls can still acquire the lock.
        #expect(box.get() == 1)
        box.set(2)
        #expect(box.get() == 2)
    }

    @Test
    func concurrentReadModifyWriteDoesNotLoseUpdates() async {
        let box = TestValueBox(0)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    for _ in 0..<100 {
                        box.withValue { $0 += 1 }
                    }
                }
            }
        }
        #expect(box.get() == 10_000)
    }

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
}
