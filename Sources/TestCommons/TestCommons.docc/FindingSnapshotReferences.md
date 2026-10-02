# Finding snapshot references

Resolve source-local and bundled references without depending on a snapshot library.

## Overview

### Supply the owning resource directory

``SnapshotReferenceDirectory/resolve(for:resourceDirectories:directoryName:)``
uses the source filename without its extension. For `ExampleTests.swift`, it first
checks `__Snapshots__/ExampleTests/` beside the source file, then checks the same
relative path under each supplied resource directory in order.

```swift
import Foundation
import TestCommons

func referencePath(for sourceFile: String, in testBundle: Bundle) -> String? {
    SnapshotReferenceDirectory.resolve(
        for: sourceFile,
        resourceDirectories: [testBundle.resourceURL].compactMap { $0 }
    )?.path
}
```

Pass `#filePath` from the calling test as `sourceFile` and the owning test bundle
as `testBundle`. Pass the resulting path to your snapshot library's directory
argument. Keeping the bundle explicit avoids finding another target's references
when two tests have the same filename.

### Handle relocated test runners

Test binaries can carry source paths from a build machine that do not exist on
the test runner. Bundle the reference directories as test resources to preserve
the layout, then supply that bundle's resource URL. Fallback also works when the
source parent exists but the actual reference directory is absent.

Only existing directories match. Regular files are skipped. If no candidate
exists, the helper returns `nil`; it never creates a directory. Snapshot libraries
that accept an optional directory can then choose their default recording location.
For a library that requires a path, choose the desired new-reference location in
the adapter rather than treating `nil` as an existing reference directory.

### Keep policy in the caller

Use `directoryName:` for a reference folder other than `__Snapshots__`. Order
resource roots deliberately when several may contain the same test name.
The helper does not scan all loaded bundles, compare images, select a recording
mode, or decide whether a simulator runtime matches the reference toolchain.
