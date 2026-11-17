#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
    import TestCommons
    import Testing

    @testable import TestCommonsXCUI

    struct LaunchArgumentsTests {
        @Test func pairsReplaceEarlierValuesAndKeepOtherFlags() {
            let arguments = replacingLaunchArguments(
                ["-A", "1", "-Flag", "-B", "2", "-A", "3", "-B"], with: [("-A", "x"), ("-B", "y")])
            #expect(arguments == ["-Flag", "-A", "x", "-B", "y"])
        }

        @Test func layoutDirectionSetsBothDirectionKeys() {
            #expect(
                layoutDirectionLaunchArguments(["-UITesting"], .rightToLeft) == [
                    "-UITesting", "-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES",
                ])
            #expect(
                layoutDirectionLaunchArguments(
                    ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"], .leftToRight) == [
                        "-AppleTextDirection", "NO", "-NSForceRightToLeftWritingDirection", "NO",
                    ])
        }

        #if os(iOS) || os(tvOS) || os(visionOS)
            @Test func contentSizeReplacesAnEarlierCategory() {
                let arguments = contentSizeLaunchArguments(
                    ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"],
                    "UICTContentSizeCategoryAccessibilityXXXL")
                #expect(
                    arguments == ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
            }
        #endif
    }
#endif
