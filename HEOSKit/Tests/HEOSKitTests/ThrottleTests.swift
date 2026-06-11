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
        try? await Task.sleep(for: .milliseconds(100))

        let values = await tracker.values
        #expect(values == [42])
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
        try? await Task.sleep(for: .milliseconds(100))

        let values = await tracker.values
        #expect(values == [3])
    }

    @Test func submitsSpacedApartAllExecute() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(30)) { value in
            await tracker.record(value)
        }

        await throttle.submit(1)
        try? await Task.sleep(for: .milliseconds(60))
        await throttle.submit(2)
        try? await Task.sleep(for: .milliseconds(60))

        let values = await tracker.values
        #expect(values == [1, 2])
    }

    // MARK: - Cancellation

    @Test func cancelPreventsExecution() async {
        let tracker = ValueTracker<Int>()
        let throttle = Throttle<Int>(interval: .milliseconds(50)) { value in
            await tracker.record(value)
        }

        await throttle.submit(99)
        await throttle.cancel()
        try? await Task.sleep(for: .milliseconds(100))

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
        try? await Task.sleep(for: .milliseconds(60))

        let values = await tracker.values
        #expect(values == [2])
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
        try? await Task.sleep(for: .milliseconds(200))

        let errors = await errorTracker.values
        #expect(errors.count == 1)
    }

    @Test func actionErrorWithoutOnErrorDoesNotCrash() async {
        let throttle = Throttle<Int>(interval: .milliseconds(30)) { _ in
            throw TestError.intentional
        }

        await throttle.submit(1)
        try? await Task.sleep(for: .milliseconds(200))
        // No crash = pass
    }
}

// MARK: - Helpers

private enum TestError: Error {
    case intentional
}

private actor ValueTracker<V: Sendable> {
    private(set) var values: [V] = []

    func record(_ value: V) {
        values.append(value)
    }
}
