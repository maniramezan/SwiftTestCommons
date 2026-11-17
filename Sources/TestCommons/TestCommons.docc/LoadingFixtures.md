# Loading fixtures

Read bundled fixtures safely and supply deterministic values to code under test.

## Overview

### Read files from an explicit root

``FixtureDirectory`` reads data or UTF-8 text beneath one root. Pass the owning bundle
explicitly, typically `Bundle.module` in a package test, rather than searching every bundle.
Paths that escape the root through `..` or symbolic links are rejected.

```swift
import Foundation
import TestCommons

func loadUser(from bundle: Bundle) throws -> String {
    let fixtures = try FixtureDirectory(bundle: bundle, subdirectory: "Fixtures")
    return try fixtures.text(named: "users/first.json")
}
```

### Script deterministic values

``ScriptedValues`` hands out a fixed sequence, such as dates or identifiers, and applies an
explicit policy when the script runs out. Exhaustion throws ``ScriptedValues/Exhausted``,
never an error you scripted, so an unexpected extra call cannot pass a failure test.

```swift
import Foundation
import Testing
import TestCommons

@Test func identifiersComeFromTheScript() throws {
    let first = UUID()
    let second = UUID()
    var identifiers = ScriptedValues([first, second], exhaustion: .repeatLast)
    #expect(try identifiers.next() == first)
    #expect(try identifiers.next() == second)
    #expect(try identifiers.next() == second)
    #expect(identifiers.remainingCount == 0)
}
```

`ScriptedValues` is a value type. When several callers share one script, own it in an actor
or a ``TestValueBox`` and call `next()` inside ``TestValueBox/withValue(_:)``.

### Round-trip codable values

``jsonRoundTrip(_:encoder:decoder:)`` encodes and decodes with coders you configure, so the
test exercises the same date and key strategies as production code.

```swift
import Foundation
import Testing
import TestCommons

struct Event: Codable, Equatable {
    let name: String
    let date: Date
}

@Test func eventsSurviveEncoding() throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let event = Event(name: "Launch", date: Date(timeIntervalSince1970: 0))
    #expect(try jsonRoundTrip(event, encoder: encoder, decoder: decoder) == event)
}
```

### Build an environment

``fixtureEnvironment(base:overrides:)`` returns an independent dictionary for a child process
or an injected configuration. It never mutates the current process's environment; a `nil`
override removes a key.
