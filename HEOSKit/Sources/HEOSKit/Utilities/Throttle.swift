import Foundation

/// Debounces rapid calls, only executing the action with the latest value after the interval elapses.
actor Throttle<Value: Sendable> {
    private let interval: Duration
    private let action: (Value) async throws -> Void
    private let onError: (@Sendable (Error) async -> Void)?
    private var pendingTask: Task<Void, Never>?

    init(
        interval: Duration,
        action: @escaping (Value) async throws -> Void,
        onError: (@Sendable (Error) async -> Void)? = nil
    ) {
        self.interval = interval
        self.action = action
        self.onError = onError
    }

    func submit(_ value: Value) {
        pendingTask?.cancel()
        pendingTask = Task {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            do {
                try await action(value)
            } catch {
                await onError?(error)
            }
        }
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
