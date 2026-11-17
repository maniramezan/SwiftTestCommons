#if os(macOS) || os(iOS) || os(visionOS)
    import Testing

    @testable import TestCommonsXCUI

    struct ReplaceTextTests {
        @Test(arguments: [
            (timeout: 5.0, elapsed: Duration.milliseconds(1_500), expected: 3.5),
            (timeout: 1.0, elapsed: .seconds(3), expected: 0),
            (timeout: 0, elapsed: .zero, expected: 0),
        ])
        func remainingTimeoutNeverGoesNegative(timeout: Double, elapsed: Duration, expected: Double) {
            #expect(abs(remainingTimeout(timeout, elapsed: elapsed) - expected) < 1e-9)
        }

        @Test(arguments: [
            (value: "", placeholder: nil as String?, expected: 0),
            (value: "abc", placeholder: nil, expected: 3),
            (value: "Search", placeholder: "Search", expected: 0),
            (value: "Search", placeholder: "", expected: 6),
            (value: "e\u{301}", placeholder: nil, expected: 2),
            (value: "می\u{200C}خواهم", placeholder: "Name", expected: 8),
        ])
        func deletionsCoverEveryScalarButSkipPlaceholders(value: String, placeholder: String?, expected: Int) {
            #expect(deletionCount(for: value, placeholder: placeholder) == expected)
        }
    }
#endif
