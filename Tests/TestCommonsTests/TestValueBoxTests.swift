import Foundation
import Testing
import TestCommons

struct TestValueBoxTests {
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
}
