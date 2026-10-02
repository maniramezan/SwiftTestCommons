# ``TestCommons``

Reusable geometry, dependency spies, and isolated resources for Swift tests and tools.

## Overview

The core product uses Foundation, conditional CoreGraphics, and Synchronization without importing
XCTest, Swift Testing, or SwiftUI. It can be linked into shipping tools as well as test
targets. It requires Swift 6 language mode and supports iOS 18 and macOS 15 or later, plus Linux for the core helpers.

Use the separate `TestCommonsXCUI` product for XCTest assertions and UI interactions.
Keep application fixtures, launch settings, database schemas, and snapshot policies in
the owning application; pass only generic values and resource locations to these helpers.

## Topics

### Guides

- <doc:CheckingReadingOrder>
- <doc:RecordingDependencyCalls>
- <doc:IsolatingTemporaryStorage>
- <doc:FindingSnapshotReferences>

### Frame geometry

- ``ReadingDirection``
- ``ReadingOrder``

### Dependency spies and failure paths

- ``CallRecorder``
- ``TestValueBox``
- ``TestError``

### Isolated resources

- ``TemporaryDirectory``
- ``TemporaryUserDefaults``

### Snapshot integration

- ``SnapshotReferenceDirectory``

### Async coordination and observation

- ``AsyncGate``
- ``waitUntil(timeout:pollInterval:operation:matching:)``
- ``ObservationTimeout``
- ``observeStream(_:maxCount:timeout:until:)-(AsyncStream<Element>,_,_,_)``
- ``observeStream(_:maxCount:timeout:until:)-(AsyncThrowingStream<Element,Error>,_,_,_)``
- ``StreamObservation``

### Fixtures and layout checks

- ``ScriptedValues``
- ``FixtureDirectory``
- ``FrameGeometry``
- ``jsonRoundTrip(_:encoder:decoder:)``
- ``fixtureEnvironment(base:overrides:)``
