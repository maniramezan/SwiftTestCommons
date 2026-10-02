# Checking reading order

Check horizontal frame order without depending on a view or testing framework.

## Overview

### Use a common coordinate space

``ReadingOrder`` compares frame centers in screen coordinates, where increasing
horizontal coordinates point right. Convert frames into the same coordinate space
before comparing them. Screen-coordinate vertical centers identify rows; the helpers
do not implement reading order across multiple rows.

```swift
import CoreGraphics
import TestCommons

let leading = CGRect(x: 80, y: 20, width: 30, height: 30)
let trailing = CGRect(x: 40, y: 20, width: 30, height: 30)
let follows = ReadingOrder.follows(trailing, leading, in: .rightToLeft)
assert(follows)
```

Equal horizontal centers do not advance in either direction. Overlap is allowed;
use an additional edge or intersection check if separation matters to your test.

### Choose a row tolerance

``ReadingOrder/defaultRowTolerance`` is one point. A difference **equal** to the
tolerance does not match because the boundary is exclusive. Pass the same tolerance
to row selection and order validation when rendering produces fractional offsets.

Empty, null, infinite, or nonfinite frames never share a row. Neither do frames
compared with zero, negative, infinite, or NaN tolerances. This prevents unavailable
geometry from being interpreted as a successful layout check.

### Select a pair in a grid

``ReadingOrder/firstAdjacentPair(in:successor:rowTolerance:)`` searches logical keys
in ascending order. Missing successors and row breaks are skipped; the next dictionary
key is not substituted for a missing logical successor.

```swift
import CoreGraphics
import TestCommons

let frames: [Int: CGRect] = [
    1: CGRect(x: 80, y: 0, width: 30, height: 30),
    2: CGRect(x: 0, y: 40, width: 30, height: 30),
    3: CGRect(x: 40, y: 40, width: 30, height: 30),
]
let pair = ReadingOrder.firstAdjacentPair(in: frames) { key in
    // The terminal key does not advance, so it is safely skipped.
    key < 3 ? key + 1 : key
}
if let pair {
    assert(ReadingOrder.follows(pair.second, pair.first, in: .leftToRight))
}
```

The successor closure is called for each examined key, including a terminal key if
the search reaches it. Avoid arithmetic overflow and handle every input safely.
Selection only checks rows; validate the returned pair's direction separately.

### Report a UI test failure

In an XCTest UI target, import `TestCommonsXCUI` and use `XCTAssertReadingOrder`.
Pass the frames, direction, optional context label, and `rowTolerance:`. Its failure
message includes both frames and points at the calling test by default.
