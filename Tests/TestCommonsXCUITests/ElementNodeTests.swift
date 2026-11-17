#if os(macOS) || os(iOS) || os(visionOS)
    import CoreGraphics
    import Testing

    @testable import TestCommonsXCUI

    struct ElementNodeTests {
        private func scroll(_ frame: CGRect, _ children: [ElementNode] = []) -> ElementNode {
            ElementNode(kind: .scrollContainer, identifier: "", frame: frame, children: children)
        }

        private func element(_ identifier: String, _ frame: CGRect, _ children: [ElementNode] = []) -> ElementNode {
            ElementNode(kind: .other, identifier: identifier, frame: frame, children: children)
        }

        @Test
        func theSmallestEnclosingContainerOwnsTheTarget() throws {
            let target = CGRect(x: 500, y: 600, width: 100, height: 40)
            let detail = CGRect(x: 462, y: 0, width: 494, height: 440)
            let tree = element(
                "", CGRect(x: 0, y: 0, width: 956, height: 440),
                [
                    scroll(
                        CGRect(x: 0, y: 0, width: 956, height: 440),
                        [
                            scroll(CGRect(x: 0, y: 0, width: 300, height: 440)),
                            scroll(detail, [element("row-9", target)]),
                        ])
                ])
            let owner = try #require(tree.owningScrollContainer(of: "row-9"))
            #expect(owner.container == detail)
            #expect(owner.target == target)
        }

        @Test
        func emptyContainersAndUnknownIdentifiersAreIgnored() {
            let tree = scroll(.zero, [element("row", CGRect(x: 0, y: 0, width: 10, height: 10))])
            #expect(tree.owningScrollContainer(of: "row") == nil)
            #expect(tree.owningScrollContainer(of: "missing") == nil)
            #expect(tree.owningScrollContainer(of: "") == nil)
        }

        @Test
        func signaturesChangeWhenAnyFrameMoves() {
            let row = CGRect(x: 0, y: 100, width: 10, height: 10)
            let before = scroll(CGRect(x: 0, y: 0, width: 100, height: 100), [element("row", row)])
            let after = scroll(
                CGRect(x: 0, y: 0, width: 100, height: 100), [element("row", row.offsetBy(dx: 0, dy: -50))])
            #expect(before.frameSignature == [CGRect(x: 0, y: 0, width: 100, height: 100), row])
            #expect(before.frameSignature != after.frameSignature)
        }
    }
#endif
