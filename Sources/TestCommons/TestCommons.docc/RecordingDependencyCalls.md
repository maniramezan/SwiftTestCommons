# Recording dependency calls

Capture arguments and synchronous callback state with Swift 6 isolation checks.

## Overview

### Record asynchronous arguments

``CallRecorder`` stores any `Sendable` value. Record a neutral value or your own
application-specific argument type without adding that type to this package.

```swift
import TestCommons

func checkRecordedCalls() async {
    let recorder = CallRecorder<String>()
    let dependency: @Sendable (String) async -> Void = { argument in
        await recorder.record(argument)
    }

    await dependency("first")
    await dependency("second")
    let values = await recorder.values()
    let last = await recorder.lastValue()
    assert(values == ["first", "second"])
    assert(last == "second")
}
```

Await the operation under test before inspecting the recorder. A snapshot does not
wait for pending work. Sequential awaited calls preserve their order; concurrent
tasks are recorded in arrival order, which can differ between runs. Assert counts
or unordered contents unless the operation under test guarantees an order.

Returned arrays are snapshots: subsequent recording does not append to an earlier
array. The recorder retains its history for its lifetime, so create one per test.

### Track synchronous callback state

Use ``TestValueBox`` when an injected callback must remain synchronous. It protects
a `Sendable` value with a mutex and can be captured by `@Sendable` closures.

```swift
import TestCommons

let calls = TestValueBox(0)
let callback: @Sendable () -> Void = {
    calls.withValue { $0 += 1 }
}
callback()
assert(calls.get() == 1)
```

Use ``TestValueBox/withValue(_:)`` to read and modify in one critical section.
Calling `get()` and then `set(_:)` separately allows another callback to update the
value between those operations and can lose an increment.

The mutation closure runs synchronously. Keep it short, do not suspend, and do not
call a method on the same box from inside it: the mutex is not recursive. Throwing
releases the lock but does not roll back mutations already made. The generic
`Sendable` constraint prevents using an unprotected mutable reference as the state.

### Exercise failure paths

``TestError`` is an equatable error without a payload. Throw it from a dependency
when the test needs an error but does not depend on a domain-specific error type.
All instances compare equal. Use an application error when its associated values
or identity are part of the behavior being tested.
