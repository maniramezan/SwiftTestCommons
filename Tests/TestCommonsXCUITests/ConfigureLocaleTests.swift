#if os(macOS) || os(iOS)
    import Testing

    @testable import TestCommonsXCUI

    struct ConfigureLocaleTests {
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
    }
#endif
