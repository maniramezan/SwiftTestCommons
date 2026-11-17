# ``TestCommons``

Reusable geometry, dependency spies, and isolated resources for Swift tests and tools.

## Overview

The core product uses Foundation, conditional CoreGraphics, and Synchronization without importing
XCTest, Swift Testing, or SwiftUI. It can be linked into shipping tools as well as test
targets. It requires Swift 6 language mode and supports iOS and Mac Catalyst 18, macOS 15, tvOS 18,
visionOS 2, and watchOS 11 or later, plus Linux.

Use the separate `TestCommonsXCUI` product for XCTest assertions and UI interactions.
Keep application fixtures, launch settings, database schemas, and snapshot policies in
the owning application; pass only generic values and resource locations to these helpers.

## Topics

### Guides

- <doc:CheckingReadingOrder>
- <doc:RecordingDependencyCalls>
- <doc:FakingDependenciesAndTime>
- <doc:ObservingAsynchronousState>
- <doc:LoadingFixtures>
- <doc:IsolatingTemporaryStorage>
- <doc:FindingSnapshotReferences>

### Frame geometry

- ``ReadingDirection``
- ``ReadingOrder``
- ``FrameGeometry``

### Dependency spies and failure paths

- ``CallRecorder``
- ``TestValueBox``
- ``TestError``

### Test doubles

- ``ScriptedResponder``
- ``ScriptedValues``
- ``StubbedURLSession``
- ``StubResponse``
- ``ManualClock``

### Async coordination and observation

- ``AsyncGate``
- ``waitUntil(timeout:pollInterval:isolation:operation:matching:)``
- ``ObservationTimeout``
- ``observeStream(_:maxCount:timeout:until:)``
- ``StreamObservation``

### Fixtures

- ``FixtureDirectory``
- ``jsonRoundTrip(_:encoder:decoder:)``
- ``fixtureEnvironment(base:overrides:)``

### Isolated resources

- ``TemporaryDirectory``
- ``TemporaryUserDefaults``

### Snapshot integration

- ``SnapshotReferenceDirectory``
