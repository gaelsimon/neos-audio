import Testing
import Foundation
@testable import HEOSKit

@Suite("Throttle Tests")
struct ThrottleTests {

    // MARK: - Basic Execution

    @Test func submitExecutesActionAfterInterval() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(50)) { value in
            await tracker.record(value)
        }

        await throttle.submit(42)

        await waitUntil { await tracker.values == [42] }
        #expect(await tracker.values == [42])
    }

    // MARK: - Debounce Behavior

    @Test func rapidSubmitsOnlyExecuteLatestValue() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(50)) { value in
            await tracker.record(value)
        }

        await throttle.submit(1)
        await throttle.submit(2)
        await throttle.submit(3)

        await waitUntil { await tracker.values == [3] }
        #expect(await tracker.values == [3])
    }

    @Test func submitsSpacedApartAllExecute() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(30)) { value in
            await tracker.record(value)
        }

        await throttle.submit(1)
        await waitUntil { await tracker.values == [1] }
        await throttle.submit(2)
        await waitUntil { await tracker.values == [1, 2] }

        #expect(await tracker.values == [1, 2])
    }

    // MARK: - Cancellation

    @Test func cancelPreventsExecution() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(50)) { value in
            await tracker.record(value)
        }

        await throttle.submit(99)
        await throttle.cancel()
        // Negative assertion: wait well past the interval, then confirm nothing fired.
        try? await Task.sleep(for: .milliseconds(250))

        let values = await tracker.values
        #expect(values.isEmpty)
    }

    @Test func submitAfterCancelWorks() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(30)) { value in
            await tracker.record(value)
        }

        await throttle.submit(1)
        await throttle.cancel()
        await throttle.submit(2)

        await waitUntil { await tracker.values == [2] }
        #expect(await tracker.values == [2])
    }

    // MARK: - Error Handling

    @Test func actionErrorCallsOnError() async {
        let errorTracker = ValueTracker<String>()
        let throttle = Throttle<Int>(
            interval: .milliseconds(30),
            action: { _ in throw TestError.intentional },
            onError: { error in
                await errorTracker.record(error.localizedDescription)
            }
        )

        await throttle.submit(1)

        await waitUntil { await errorTracker.values.count == 1 }
        #expect(await errorTracker.values.count == 1)
    }

    @Test func actionErrorWithoutOnErrorDoesNotCrash() async {
        let ran = ValueTracker<Bool>()
        let throttle = Throttle<Int>(interval: .milliseconds(30)) { _ in
            await ran.record(true)
            throw TestError.intentional
        }

        await throttle.submit(1)
        // The throwing action runs and the missing onError must not crash.
        await waitUntil { await ran.values == [true] }
        #expect(await ran.values == [true])
    }
}

// MARK: - Helpers

/// Polls until `condition` holds or the timeout elapses — a deterministic replacement for the
/// fixed sleeps that flaked under CI load. A genuine failure still surfaces after the timeout.
private func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @Sendable () async -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

private enum TestError: Error {
    case intentional
}

private actor ValueTracker<V: Sendable> {
    private(set) var values: [V] = []

    func record(_ value: V) {
        values.append(value)
    }
}
