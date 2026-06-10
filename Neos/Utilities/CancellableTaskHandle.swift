import Foundation

/// Holds a single cancellable `Task` for a `@MainActor` view model.
///
/// Wraps the `@ObservationIgnored nonisolated(unsafe)` storage pattern needed because
/// `Task` is not `Sendable`. Safe because all callers are `@MainActor`-isolated and
/// `Task.cancel()` is thread-safe; `deinit` may call `cancel()` off the main actor.
@MainActor
final class CancellableTaskHandle {
    @ObservationIgnored nonisolated(unsafe) private var task: Task<Void, Never>?

    init() {}

    /// Cancels any in-flight task and stores the new one.
    func replace(with newTask: Task<Void, Never>) {
        task?.cancel()
        task = newTask
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
