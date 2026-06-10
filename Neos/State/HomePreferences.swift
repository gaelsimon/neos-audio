import Foundation

enum HomePreferences {
    private static let key = "homeHiddenServiceSIDs"

    static func hiddenSIDs() -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        return Set(array)
    }

    static func setHiddenSIDs(_ sids: Set<Int>) {
        UserDefaults.standard.set(Array(sids), forKey: key)
    }

    static func isHidden(sid: Int) -> Bool {
        hiddenSIDs().contains(sid)
    }

    static func toggleVisibility(sid: Int) {
        var sids = hiddenSIDs()
        if sids.contains(sid) {
            sids.remove(sid)
        } else {
            sids.insert(sid)
        }
        setHiddenSIDs(sids)
    }
}
