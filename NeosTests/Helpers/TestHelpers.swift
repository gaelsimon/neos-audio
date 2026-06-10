import XCTest

/// Yield control enough times for @MainActor Task { } blocks inside
/// view models to execute. Replaces `Task.sleep(for: .milliseconds(50-100))`
/// which added ~10 seconds of unnecessary wait to the test suite.
///
/// Since tests, view models, and mocks are all @MainActor, a series of
/// `Task.yield()` calls lets the cooperative executor run pending tasks.
@MainActor
func yieldForTask() async {
    for _ in 0..<5 {
        await Task.yield()
    }
}
