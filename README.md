# TestCommons

Shared test helpers for Swift packages and tools.

| Product | Imports | Link it into |
|---|---|---|
| `TestCommons` | Foundation / conditional CoreGraphics / Synchronization | Anything, including shipping tools |
| `TestCommonsXCUI` | XCTest | UI test targets only |
| `TestCommonsUI` | SwiftUI / AppKit or UIKit | Hosted-view test targets |

Requires Swift 6 language mode, iOS 18 or macOS 15. The core product also builds and tests on Linux.

## Installation

Add the package, then depend on the products each target needs:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftTestCommons", .upToNextMinor(from: "0.3.0")),
],
targets: [
    .testTarget(
        name: "AppTests",
        dependencies: [.product(name: "TestCommons", package: "SwiftTestCommons")]
    ),
    .testTarget(
        name: "AppUITests",
        dependencies: [.product(name: "TestCommonsXCUI", package: "SwiftTestCommons")]
    ),
]
```

Use the latest [release](https://github.com/maniramezan/SwiftTestCommons/releases). Before 1.0, a minor
release can contain breaking changes, so pin with `.upToNextMinor(from:)` rather than `from:`.
Tags are bare SemVer (`0.3.0`), never `v0.3.0`.

## Reading order and frame geometry

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

In a UI test, pass `rowTolerance:` to use the same tolerance as the geometry helper:

```swift
XCTAssertReadingOrder(first: dayOne.frame, second: dayTwo.frame, direction: .rightToLeft, "Persian")
```

`FrameGeometry` checks containment, overlap, horizontal gaps, and horizontal alignment
using valid frames in one coordinate space. `ReadingOrder` uses the same validity checks.

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

## Test doubles

`ScriptedResponder<Request, Response>` records requests and answers call *n* with scripted
outcome *n*. `hold(call:)` suspends one call so in-flight state can be asserted; running out
of outcomes throws `ScriptedResponder.Exhausted`, never a scripted error.

```swift
let responder = ScriptedResponder<String, Int>([.failure(TestError()), .success(42)])
let fetch: @Sendable (String) async throws -> Int = { try await responder.respond(to: $0) }
```

`StubbedURLSession` answers one session's requests in process, from a handler or a list of
`StubResponse`s, and records them with bodies. Sessions are isolated, so parallel tests can stub
independently, on Apple platforms and Linux. Keep the stub alive while its session is in use,
and invalidate it when the test finishes:

```swift
let stub = try StubbedURLSession(responses: [.json(#"{"id":1}"#), .text("busy", statusCode: 503)])
defer { stub.invalidate() }
let client = APIClient(session: stub.session)
```

`ManualClock` is a `Clock` whose sleeps resume only when a test calls `advance(by:)` or
`advance(to:)`. Wait with `waitForSleepers(_:)` before advancing.

`ScriptedValues` supplies deterministic sequences of dates, UUIDs, or any other sendable
fixtures, with fail, repeat-last, and fallback exhaustion policies. Own mutable scripts in
an actor or a `TestValueBox` when sharing them.

## Async coordination

`AsyncGate` is a cancellation-aware one-shot signal with multiple waiters. Use
`waiterCount` to establish that work has suspended before opening it.

`waitUntil` uses a monotonic deadline and throws `ObservationTimeout` carrying the last
observation. Observation closures must return promptly and cooperate with cancellation.

```swift
let count = try await waitUntil(timeout: .seconds(2)) { await model.count } matching: { $0 >= 3 }
```

`observeStream` consumes any sendable `AsyncSequence`, with both a time budget and an
event budget. It returns collected events with a matched, finished,
limit-reached, or timed-out outcome. Source errors and caller cancellation propagate.
A count limit alone cannot prevent a stalled stream from hanging.

## Isolated storage and fixtures

Each temporary resource has a unique name so parallel tests cannot share state:

```swift
let directory = try TemporaryDirectory(prefix: "ImportTests")
defer { try? directory.remove() }
let file = try directory.write(Data("{}".utf8), named: "fixtures/empty.json")

let preferences = try TemporaryUserDefaults()
defer { preferences.remove() }
preferences.defaults.set(true, forKey: "enabled")
```

Cleanup is explicit and repeatable. The preferences helper clears its own suite only;
pass `preferences.defaults` to the code under test. `preferences.suiteName` lets another
instance reopen the same suite for persistence tests.

`FixtureDirectory` reads UTF-8 text or data from an explicit root or owning bundle.
Relative paths escaping their resource root are rejected. `jsonRoundTrip` accepts
caller-owned coders, and `fixtureEnvironment` builds independent dictionaries without
mutating process-global environment variables.

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

## Hosted SwiftUI views

`TestCommonsUI.HostedView` owns a platform hierarchy, renders PNG bytes, waits for
stable rendered frames, and compares against a caller-supplied blank reference:

```swift
let hosted = HostedView(Text("Ready"), size: CGSize(width: 200, height: 100))
defer { hosted.close() }
_ = hosted.waitForStableRender()
let png = hosted.renderPNG()
```

Call `close()` explicitly, normally in `defer`. Stable pixels do not establish content
arrival. Serialize suites that pump the main run loop.

## UI tests

`TestCommonsXCUI` waits for existence, enabled state, hittability, absence, labels, and values.
Call them from the main actor and pass your test's timeout:

```swift
TestCommonsXCUI.waitForEnabled(submitButton, timeout: 5)
TestCommonsXCUI.waitForValue("ready", on: statusElement, timeout: 5, named: "Status")
```

Each reports an XCTest failure at the caller with the element's debug description and
returns a discardable success flag. State waits require the element to exist as well as
match the requested state, within one timeout budget. Label waits observe labels; value
waits observe values. Qualify the helper with `TestCommonsXCUI` when a test target still
has a local helper with the same name.

`container.scrollUpUntilHittable(child, maxAttempts:)` and `scrollDownUntilHittable`
perform bounded swipes and return whether the child exists and is hittable. They check
after the final swipe and make no swipes for nonpositive budgets. Assert the returned
flag when revealing the child is required for the next interaction.

`attachDiagnostics` captures a screenshot and accessibility hierarchy with caller-chosen
attachment lifetime. `configureLocale` replaces prior Apple language/locale arguments while
preserving app flags. `uniqueHittableElement` reports ambiguous visible queries. `replaceText`
supports plain fields exposing their actual string contents, an explicit trailing caret
coordinate, and final value verification. Secure or placeholder-only fields need a
caller-owned interaction strategy.

## Related packages

[TestCommonsMacroTesting](https://github.com/maniramezan/TestCommonsMacroTesting) is an independent
package. Its Swift Testing macro-expansion adapter supports diagnostics and fix-its and preserves
failure locations, so core consumers never resolve SwiftSyntax.

`Integrations/ConsumerTests` verifies generated UserDefaultMacro code against isolated
preferences at TestCommons' deployment minimums without raising UserDefaultMacro's
platform requirements. It uses the sibling UserDefaultMacro checkout by default;
`USERDEFAULT_MACRO_PATH` overrides it. Local paths are used only by this harness.

```sh
swift test --package-path Integrations/ConsumerTests
```

## Documentation

Each product has a DocC catalog with API references and usage guides:

- [TestCommons](Sources/TestCommons/TestCommons.docc/TestCommons.md): geometry, dependency spies,
  test doubles, async observation, isolated storage, and snapshot reference resolution.
- [TestCommonsUI](Sources/TestCommonsUI/TestCommonsUI.docc/TestCommonsUI.md): hosted rendering and
  frame observation.
- [TestCommonsXCUI](Sources/TestCommonsXCUI/TestCommonsXCUI.docc/TestCommonsXCUI.md): element waits,
  bounded scrolling, layout assertions, and adapters that preserve failure locations.

With Xcode selected and its iOS Simulator SDK installed, build and validate all archives:

```sh
python3 Scripts/build-documentation.py
```

The check treats DocC warnings as errors, requires documentation and Topics curation
for every declared public API, checks parameter and return coverage, and type-checks
each Swift guide example. Compiler-synthesized and inherited members are excluded
from the declared-API coverage count. CI runs the same check.

Open a generated archive in Xcode:

```sh
open .build/documentation/Build/Products/Debug-iphonesimulator/TestCommons.doccarchive
open .build/documentation/Build/Products/Debug-iphonesimulator/TestCommonsUI.doccarchive
open .build/documentation/Build/Products/Debug-iphonesimulator/TestCommonsXCUI.doccarchive
```

`.spi.yml` configures hosted documentation on the [Swift Package Index](https://swiftpackageindex.com).

## Contributing

Work on a feature branch and merge through a pull request; run
`git config --local core.hooksPath .githooks` once per checkout to block direct pushes to `main`.
Run these before opening a pull request (CI runs the same checks):

```sh
swift build
swift test --enable-code-coverage
python3 Scripts/check-coverage.py --diff-base origin/main
swift format lint --strict --recursive Package.swift Sources Tests
python3 Scripts/build-documentation.py
```

- Each product keeps a line-coverage floor (`TARGET_THRESHOLDS` in the script). Floors only go up.
- At least 90% of executable lines changed since the merge base must be covered. In GitHub
  Actions, each uncovered changed line is annotated on the pull request.
- `TestCommonsXCUI` is exempt from the changed-line check because its `XCUIElement` waits need a
  UI-test host. Keep its floor rising by moving pure logic into internal functions with unit tests.

Conventional Commits drive automated tagging and GitHub Releases (see `.github/workflows/release.yml`).
There is no `CHANGELOG.md`; release notes live on the GitHub Release. See [AGENTS.md](AGENTS.md)
for code conventions.

## License

MIT.
