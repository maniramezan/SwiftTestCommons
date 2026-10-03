#if canImport(SwiftUI)
    import Testing

    // Hosted rendering pumps the main run loop, which can start other main-actor tests mid-render.
    // Nesting every rendering suite here serializes them with each other, not only internally.
    @MainActor
    @Suite(.serialized)
    struct RenderingTests {}
#endif
