import Testing

@testable import TestCommonsXCUI

@MainActor
struct ScrollingTests {
    @Test
    func alreadyVisibleElementNeedsNoSwipes() {
        var swipes = 0
        let result = revealElement(
            maxAttempts: 3, isHittable: { true }, swipe: { swipes += 1 })
        #expect(result)
        #expect(swipes == 0)
    }

    @Test(arguments: [1, 3])
    func visibilityAfterTheLastSwipeIsReported(maxAttempts: Int) {
        var swipes = 0
        let result = revealElement(
            maxAttempts: maxAttempts,
            isHittable: { swipes == maxAttempts },
            swipe: { swipes += 1 })
        #expect(result)
        #expect(swipes == maxAttempts)
    }

    @Test
    func stopsAsSoonAsTheElementIsHittable() {
        var swipes = 0
        let result = revealElement(
            maxAttempts: 8, isHittable: { swipes >= 2 }, swipe: { swipes += 1 })
        #expect(result)
        #expect(swipes == 2)
    }

    @Test(arguments: [-1, 0, 3])
    func exhaustedBudgetReturnsFalseWithoutExtraSwipes(maxAttempts: Int) {
        var swipes = 0
        let result = revealElement(
            maxAttempts: maxAttempts, isHittable: { false }, swipe: { swipes += 1 })
        #expect(result == false)
        #expect(swipes == max(0, maxAttempts))
    }
}
