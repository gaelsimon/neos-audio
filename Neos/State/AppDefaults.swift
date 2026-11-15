import Foundation

/// The app's settings and caches. Demo mode gets a store of its own, emptied at each launch.
enum AppDefaults {
    static let demoSuite = "com.galela.neos.demo"

    static let store = makeStore(demo: DemoSession.isActive)

    static func makeStore(demo: Bool, suite: String = demoSuite) -> UserDefaults {
        guard demo, let store = UserDefaults(suiteName: suite) else { return .standard }
        store.removePersistentDomain(forName: suite)
        return store
    }
}
