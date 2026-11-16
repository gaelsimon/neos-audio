import Foundation

/// The app's settings and files. Demo mode gets a store and a folder of its own, emptied at each launch.
enum AppDefaults {
    static let demoSuite = "com.galela.neos.demo"

    static let store = makeStore(demo: DemoSession.isActive)
    static let supportDirectory = makeSupportDirectory(demo: DemoSession.isActive)

    static func makeStore(demo: Bool, suite: String = demoSuite) -> UserDefaults {
        guard demo, let store = UserDefaults(suiteName: suite) else { return .standard }
        store.removePersistentDomain(forName: suite)
        return store
    }

    static func makeSupportDirectory(demo: Bool, in base: URL = .applicationSupportDirectory) -> URL {
        let directory = base.appendingPathComponent(demo ? "Neos-demo" : "Neos", isDirectory: true)
        if demo {
            try? FileManager.default.removeItem(at: directory)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
