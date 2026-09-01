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

/// Yields until `condition` holds, or the deadline passes.
///
/// A fixed number of yields is enough for one hop, but a view model that awaits a
/// second request before publishing needs more turns than a loaded machine may give
/// it, which is how a passing test becomes a CI failure.
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () async -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(5))
    }
    XCTFail("Condition not met within \(timeout)s", file: file, line: line)
}
