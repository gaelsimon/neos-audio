import Foundation

/// The screens that can show the toast, by how many sheets deep they sit: the deepest shows it, whatever order they came in.
struct ToastHosts: Equatable {
    private(set) var depths: [UUID: Int] = [:]

    mutating func enter(_ id: UUID, depth: Int) {
        depths[id] = depth
    }

    mutating func leave(_ id: UUID) {
        depths[id] = nil
    }

    func isFrontmost(depth: Int) -> Bool {
        depths.values.max() == depth
    }
}
