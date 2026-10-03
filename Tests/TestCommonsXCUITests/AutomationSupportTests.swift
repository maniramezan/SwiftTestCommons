#if os(macOS) || os(iOS)
    import Testing

    @testable import TestCommonsXCUI

    struct AutomationSupportTests {
        @Test func localeArgumentsAreAppendedAfterAppFlags() {
            let arguments = localeLaunchArguments(["-UITesting"], language: "fa", locale: "fa_IR")
            #expect(arguments == ["-UITesting", "-AppleLanguages", "(fa)", "-AppleLocale", "fa_IR"])
        }

        @Test func priorLocaleArgumentsAreReplacedWithoutTouchingOtherFlags() {
            let arguments = localeLaunchArguments(
                ["-AppleLanguages", "(en)", "-Reset", "-AppleLocale", "en_US", "-AppleLanguages", "(de)"],
                language: "ar", locale: "ar_SA")
            #expect(arguments == ["-Reset", "-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"])
        }

        @Test func aTrailingKeyWithoutAValueIsRemoved() {
            let arguments = localeLaunchArguments(["-Flag", "-AppleLocale"], language: "en", locale: "en_GB")
            #expect(arguments == ["-Flag", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"])
        }

        @Test(arguments: [
            (timeout: 5.0, elapsed: Duration.milliseconds(1_500), expected: 3.5),
            (timeout: 1.0, elapsed: .seconds(3), expected: 0),
            (timeout: 0, elapsed: .zero, expected: 0),
        ])
        func remainingTimeoutNeverGoesNegative(timeout: Double, elapsed: Duration, expected: Double) {
            #expect(abs(remainingTimeout(timeout, elapsed: elapsed) - expected) < 1e-9)
        }
    }
#endif
