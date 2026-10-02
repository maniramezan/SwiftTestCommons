# TestCommons

Shared test helpers for Swift packages and tools.

| Product | Imports | Link it into |
|---|---|---|
| `TestCommons` | Foundation / CoreGraphics / Synchronization | Anything, including shipping tools |
| `TestCommonsXCUI` | XCTest | UI test targets only |

## Reading order (RTL / LTR)

`ReadingOrder` is pure frame geometry, so one implementation backs XCUITest, hosted-view tests,
and device drivers:

```swift
ReadingOrder.follows(second, first, in: .rightToLeft)
```

Rows are compared by vertical center, with an exclusive tolerance (default: one point).
Empty or nonfinite frames and nonpositive or nonfinite tolerances never match.
Horizontal order compares centers; it does not require frames to be disjoint.
`firstAdjacentPair(in:successor:rowTolerance:)` checks keys in ascending order, skipping
missing successors, row breaks, invalid frames, and successors that do not advance the key.

In a UI test:

```swift
XCTAssertReadingOrder(first: dayOne.frame, second: dayTwo.frame, direction: .rightToLeft, "Persian")
```

Pass `rowTolerance:` to use the same tolerance in the XCUI assertion as in the geometry helper.

## Dependency spies

`CallRecorder<Value: Sendable>` records arguments to asynchronous dependencies:

```swift
let recorder = CallRecorder<String>()
await recorder.record("request")
let arguments = await recorder.values()
let lastArgument = await recorder.lastValue()
```

Await the operation under test before reading the recorder. Calls from concurrent tasks
are ordered by arrival at the actor.

`TestValueBox<Value: Sendable>` supports synchronous callbacks with `get()`, `set(_:)`,
and atomic `withValue(_:)` updates:

```swift
let calls = TestValueBox(0)
let callback: @Sendable () -> Void = {
    calls.withValue { $0 += 1 }
}
callback()
```

The mutation closure must not call back into the same box. A thrown error releases the lock;
mutations made before the error remain. `TestError()` supplies a payload-free, equatable
error for failure-path tests.

## Isolated storage

Each temporary resource has a unique name so parallel tests cannot share state:

```swift
let directory = try TemporaryDirectory()
defer { try? directory.remove() }
let file = directory.url.appendingPathComponent("fixture.json")

let preferences = try TemporaryUserDefaults()
defer { preferences.remove() }
preferences.defaults.set(true, forKey: "enabled")
```

Cleanup is explicit and repeatable. The preferences helper clears its own suite only;
pass `preferences.defaults` to the code under test. `preferences.suiteName` lets another
instance reopen the same suite for persistence tests.

## Snapshot references

`SnapshotReferenceDirectory` finds an existing `__Snapshots__/<test filename>/` directory
beside the source file, then in explicitly supplied resource directories. This supports
test runners whose compiled source paths no longer exist:

```swift
let references = SnapshotReferenceDirectory.resolve(
    for: #filePath,
    resourceDirectories: [testBundle.resourceURL].compactMap { $0 }
)
```

Pass `references?.path` to your snapshot library's directory argument. A missing directory
returns `nil`, so the snapshot library can apply its default recording location. Supply the
owning test bundle instead of scanning all bundles to avoid filename collisions. Resource
directories are searched in the supplied order; `directoryName:` customizes `__Snapshots__`.
This helper does not depend on a snapshot library or choose recording/toolchain policy.

## UI waits

`TestCommonsXCUI` provides `waitForExistence`, `waitForEnabled`, `waitForValue`, and
`waitForValueContaining`. Call them from the main actor and pass your test's timeout:

```swift
TestCommonsXCUI.waitForEnabled(submitButton, timeout: 5)
TestCommonsXCUI.waitForValue("ready", on: statusElement, timeout: 5)
```

Each reports an XCTest failure at the caller with the element's debug description and
returns a discardable success flag. Value and enabled waits require the element to exist
as well as match the requested state, within one timeout budget. Qualify the helper with
`TestCommonsXCUI` when a test target still has a local helper with the same name.

`container.scrollUpUntilHittable(child, maxAttempts:)` and `scrollDownUntilHittable`
perform bounded swipes and return whether the child exists and is hittable. They check
after the final swipe and make no swipes for nonpositive budgets. Assert the returned
flag when revealing the child is required for the next interaction.

## Installation

```swift
.package(url: "https://github.com/maniramezan/TestCommons", from: "0.1.0")
```

Tags are bare SemVer (`0.1.0`), never `v0.1.0`.

## DocC documentation

Both products include DocC catalogs with API references and usage guides:

- [TestCommons](Sources/TestCommons/TestCommons.docc/TestCommons.md): geometry, dependency spies,
  isolated storage, and snapshot reference resolution.
- [TestCommonsXCUI](Sources/TestCommonsXCUI/TestCommonsXCUI.docc/TestCommonsXCUI.md): element waits,
  bounded scrolling, layout assertions, and adapters that preserve failure locations.

With Xcode selected and its iOS Simulator SDK installed, build and validate both archives:

```sh
python3 Scripts/build-documentation.py
```

The check treats DocC warnings as errors, requires documentation and Topics curation
for every declared public API, checks parameter and return coverage, and type-checks
each Swift guide example. Compiler-synthesized and inherited members are excluded
from the declared-API coverage count. CI runs the same check.

Open either generated archive in Xcode:

```sh
open .build/documentation/Build/Products/Debug-iphonesimulator/TestCommons.doccarchive
open .build/documentation/Build/Products/Debug-iphonesimulator/TestCommonsXCUI.doccarchive
```

## Conventions

Conventional Commits drive automated tagging and GitHub Releases (see `.github/workflows/release.yml`).
There is no `CHANGELOG.md`; release notes live on the GitHub Release.

## License

MIT.
