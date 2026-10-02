# Repository Guidelines

- Swift 6 language mode, swift-tools 6.2, minimum iOS 18 / macOS 15.
- `TestCommons` must stay free of XCTest, Swift Testing, and SwiftUI imports so other tools can ship it.
  Anything that imports a testing framework belongs in a separate product.
- Helpers are generic: no app, calendar, or design-system identifiers. Pass app-specific details in as parameters.
- Swift Testing (`@Test`) for this package's own tests. Comments go on their own line above the code.
- `swift build`, `swift test`, and `swift format lint --strict --recursive Package.swift Sources Tests` before every PR.
- Conventional Commits. Never add a `Co-Authored-By` trailer. Never add a `CHANGELOG.md`.
