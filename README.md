# TestCommons

Shared test helpers for Swift packages and tools.

| Product | Imports | Link it into |
|---|---|---|
| `TestCommons` | Foundation / CoreGraphics only | Anything, including shipping tools |
| `TestCommonsXCUI` | XCTest | UI test targets only |

## Reading order (RTL / LTR)

`ReadingOrder` is pure frame geometry, so one implementation backs XCUITest, hosted-view tests,
and device drivers:

```swift
ReadingOrder.follows(second, first, in: .rightToLeft)
```

In a UI test:

```swift
XCTAssertReadingOrder(first: dayOne.frame, second: dayTwo.frame, direction: .rightToLeft, "Persian")
```

## Installation

```swift
.package(url: "https://github.com/maniramezan/TestCommons", from: "0.1.0")
```

Tags are bare SemVer (`0.1.0`), never `v0.1.0`.

## Conventions

Conventional Commits drive automated tagging and GitHub Releases (see `.github/workflows/release.yml`).
There is no `CHANGELOG.md`; release notes live on the GitHub Release.

## License

MIT.
