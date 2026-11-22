import Foundation

/// The app's settings and files. Demo mode and unit tests each get a store and a folder of their own, emptied at each launch.
enum AppDefaults {
    enum Space: String {
        case app = "Neos"
        case demo = "Neos-demo"
        case tests = "Neos-tests"

        var suite: String? {
            switch self {
            case .app: nil
            case .demo: "com.galela.neos.demo"
            case .tests: "com.galela.neos.tests"
            }
        }
    }

    static let space: Space = DemoSession.isActive ? .demo : isUnitTestHost ? .tests : .app
    static let store = makeStore(space)
    static let supportDirectory = makeSupportDirectory(space)

    private static var isUnitTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func makeStore(_ space: Space, suite: String? = nil) -> UserDefaults {
        guard let name = suite ?? space.suite, let store = UserDefaults(suiteName: name) else { return .standard }
        store.removePersistentDomain(forName: name)
        return store
    }

    static func makeSupportDirectory(_ space: Space, in base: URL = .applicationSupportDirectory) -> URL {
        let directory = base.appendingPathComponent(space.rawValue, isDirectory: true)
        if space != .app {
            try? FileManager.default.removeItem(at: directory)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
