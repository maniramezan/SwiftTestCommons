#if os(macOS) || os(iOS) || os(visionOS)
    import CoreGraphics

    /// An in-memory copy of an accessibility hierarchy, read in one snapshot round trip.
    ///
    /// Resolving scroll containers from a snapshot avoids one accessibility query per
    /// candidate container and per frame read.
    struct ElementNode {
        enum Kind {
            case scrollContainer
            case other
        }

        let kind: Kind
        let identifier: String
        let frame: CGRect
        let children: [ElementNode]

        /// The frames of the smallest scroll container holding `identifier`, and of the target.
        ///
        /// Containers with empty frames are ignored. Returns nil for an empty identifier or when
        /// no container holds a matching descendant.
        func owningScrollContainer(of identifier: String) -> (container: CGRect, target: CGRect)? {
            guard !identifier.isEmpty else { return nil }
            var best: (container: CGRect, target: CGRect)?
            visit(identifier: identifier, containers: []) { containers, target in
                for container in containers where !container.isEmpty {
                    if best.map({ area(container) < area($0.container) }) ?? true {
                        best = (container, target)
                    }
                }
            }
            return best
        }

        /// Every frame in the tree, in depth-first order.
        ///
        /// Comparing signatures before and after a drag shows whether any content moved.
        var frameSignature: [CGRect] {
            [frame] + children.flatMap(\.frameSignature)
        }

        private func visit(
            identifier: String, containers: [CGRect], found: ([CGRect], CGRect) -> Void
        ) {
            if self.identifier == identifier {
                found(containers, frame)
            }
            let enclosing = kind == .scrollContainer ? containers + [frame] : containers
            for child in children {
                child.visit(identifier: identifier, containers: enclosing, found: found)
            }
        }

        private func area(_ frame: CGRect) -> CGFloat { frame.width * frame.height }
    }

    #if canImport(XCTest)
        import XCTest

        extension ElementNode {
            /// Copies a snapshot's types, identifiers, frames, and children.
            @MainActor
            init(_ snapshot: any XCUIElementSnapshot) {
                let containers: Set<XCUIElement.ElementType> = [.scrollView, .table, .collectionView]
                kind = containers.contains(snapshot.elementType) ? .scrollContainer : .other
                identifier = snapshot.identifier
                frame = snapshot.frame
                children = snapshot.children.map { ElementNode($0) }
            }
        }
    #endif
#endif
