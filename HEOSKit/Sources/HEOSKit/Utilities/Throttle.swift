import Foundation

/// Throttles rapid calls: emits the first value immediately, then at most one per interval, ending with the latest value.
actor Throttle<Value: Sendable> {
    private let interval: Duration
    private let action: (Value) async throws -> Void
    private let onError: (@Sendable (Error) async -> Void)?
    private var latestValue: Value?
    private var windowTask: Task<Void, Never>?

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
        if windowTask == nil {
            windowTask = Task { await drain(first: value) }
        } else {
            latestValue = value
        }
    }

    func cancel() {
        windowTask?.cancel()
        windowTask = nil
        latestValue = nil
    }

    /// Emits the first value, then keeps the window open one interval at a time until no new value arrives.
    private func drain(first: Value) async {
        var next: Value? = first
        while !Task.isCancelled, let value = next {
            do {
                try await action(value)
            } catch {
                await onError?(error)
            }
            try? await Task.sleep(for: interval)
            next = latestValue
            latestValue = nil
        }
        if !Task.isCancelled { windowTask = nil }
    }
}
