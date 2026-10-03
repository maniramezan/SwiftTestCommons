# Repository Guidelines

- Make changes on a feature branch and merge through a pull request. Never push directly to `main`, including force pushes or deletions.
- Enable the repository push guard in each checkout with `git config --local core.hooksPath .githooks`.
- Swift 6 language mode, swift-tools 6.2, minimum iOS 18 / macOS 15.
- `TestCommons` must stay free of XCTest, Swift Testing, and SwiftUI imports so other tools can ship it.
  Anything that imports a testing framework belongs in a separate product.
- Helpers are generic: no app, calendar, or design-system identifiers. Pass app-specific details in as parameters.
- Swift Testing (`@Test`) for this package's own tests. Comments go on their own line above the code.
- One type per file, named after the type; nested types stay with their parent. Tests mirror this:
  one `<Type>Tests.swift` per type under test. Free functions live in a file named for the feature.
- `swift build`, `swift test --enable-code-coverage`, `python3 Scripts/check-coverage.py --diff-base origin/main`,
  and `swift format lint --strict --recursive Package.swift Sources Tests` before every PR.
- CI fails when a target drops below its coverage floor or changed lines are under 90% covered.
  Raise floors in `Scripts/check-coverage.py` as coverage improves; never lower them to pass a PR.
  Extract XCUIElement-free logic from `TestCommonsXCUI` into internal functions so it can be unit tested.
- Conventional Commits. Never add a `Co-Authored-By` trailer. Never add a `CHANGELOG.md`.
