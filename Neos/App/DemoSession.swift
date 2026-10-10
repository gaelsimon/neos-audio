import AppKit

// The demo is a fresh launch; the real preferences are set aside first and put back on the next normal launch.
enum DemoSession {
    static let argument = "--demo-mode"

    // Read once at launch: a sandboxed app cannot pass arguments to its own relaunch, so a marker file asks for the demo.
    static let isActive: Bool = CommandLine.arguments.contains(argument) || consumeRequest()

    private static let folder = URL.applicationSupportDirectory.appendingPathComponent("Neos", isDirectory: true)
    private static let backupURL = folder.appendingPathComponent("preferences-before-demo.plist")
    private static let requestURL = folder.appendingPathComponent("demo-requested")

    static func start() {
        saveSnapshot()
        FileManager.default.createFile(atPath: requestURL.path, contents: nil)
        relaunch()
    }

    static func leave() {
        relaunch()
    }

    private static func consumeRequest() -> Bool {
        guard FileManager.default.fileExists(atPath: requestURL.path) else { return false }
        try? FileManager.default.removeItem(at: requestURL)
        return true
    }

    static func restoreIfNeeded() {
        guard !isActive,
              let id = Bundle.main.bundleIdentifier,
              let data = try? Data(contentsOf: backupURL),
              let domain = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return }
        UserDefaults.standard.setPersistentDomain(domain, forName: id)
        try? FileManager.default.removeItem(at: backupURL)
    }

    private static func saveSnapshot() {
        guard let id = Bundle.main.bundleIdentifier,
              !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        let domain = UserDefaults.standard.persistentDomain(forName: id) ?? [:]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: backupURL)
    }

    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
