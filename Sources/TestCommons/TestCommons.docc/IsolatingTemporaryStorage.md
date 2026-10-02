# Isolating temporary storage

Give each parallel test its own directory and preferences suite with explicit cleanup.

## Overview

### Create a scratch directory

``TemporaryDirectory/init()`` creates an empty UUID-named directory beneath the
system temporary directory. Use its URL to inject file locations into the code
under test.

```swift
import Foundation
import TestCommons

func checkFileRoundTrip() throws {
    let directory = try TemporaryDirectory()
    defer { try? directory.remove() }

    let file = directory.url.appendingPathComponent("payload.txt")
    let payload = Data("example".utf8)
    try payload.write(to: file)
    let restored = try Data(contentsOf: file)
    assert(restored == payload)
}
```

Cleanup is explicit. Finish all asynchronous work that uses the directory before
calling ``TemporaryDirectory/remove()``. Copies share one directory and do not
coordinate concurrent cleanup. Removal deletes all contents, tolerates an already
missing directory, and propagates other file-system errors.

The `defer` example treats cleanup as best effort. If cleanup success is part of
the behavior under test, call `try directory.remove()` explicitly and assert the
resulting file-system state instead of discarding the error.

### Isolate preferences writes

``TemporaryUserDefaults`` creates a unique persistent suite. Inject ``TemporaryUserDefaults/defaults``
instead of changing `UserDefaults.standard`. Its ``TemporaryUserDefaults/suiteName``
can reopen the same suite to test persistence across client instances.

```swift
import Foundation
import TestCommons

func checkPreferencesRoundTrip() throws {
    let preferences = try TemporaryUserDefaults()
    defer { preferences.remove() }

    preferences.defaults.set(true, forKey: "enabled")
    if let reopened = UserDefaults(suiteName: preferences.suiteName) {
        assert(reopened.bool(forKey: "enabled"))
    } else {
        throw TemporaryUserDefaults.CreationError.unavailableSuite(preferences.suiteName)
    }
}
```

``TemporaryUserDefaults/remove()`` clears the owned persistent domain and is safe
to repeat. It does not clear registered defaults, global defaults, other suites,
or the standard suite. Reads still use Foundation's normal search domains;
choose test keys carefully if other code registers fallback values.

Copies refer to the same preferences instance and suite. The wrapper does not
declare `Sendable`; do not assume it can be transferred between isolated contexts.
Create separate wrappers for independently running tests. Cleanup is not automatic
on deinitialization, and later writes can populate a cleared suite again.
