import Foundation

/// Lightweight request-ID tracker for stale-response rejection.
///
/// Each ViewModel that performs cancellable async work creates one
/// (or more) instances.  Call `next()` before launching a request,
/// then `isCurrent(_:)` in every async continuation to bail out if
/// a newer request has been issued in the meantime.
@MainActor
final class RequestTracker {
    private var currentID: Int = 0

    /// Increment and return the new request ID.
    func next() -> Int {
        currentID += 1
        return currentID
    }

    /// Returns `true` when `id` still matches the latest request.
    func isCurrent(_ id: Int) -> Bool {
        id == currentID
    }
}
