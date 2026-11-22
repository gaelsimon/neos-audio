import Foundation
import Testing
@testable import Neos

struct AppDefaultsTests {
    private let suite = "com.galela.neos.tests.\(UUID().uuidString)"

    @Test func theAppKeepsItsSettingsInTheStandardStore() {
        #expect(AppDefaults.makeStore(.app) === UserDefaults.standard)
    }

    @Test func theTestsRunOnAStoreOfTheirOwn() {
        #expect(AppDefaults.store !== UserDefaults.standard)
    }

    @Test func theTestsKeepTheirFilesOutOfTheAppsFolder() {
        #expect(AppDefaults.supportDirectory.lastPathComponent == "Neos-tests")
    }

    @Test func demoModeStartsFromAnEmptyStore() throws {
        let earlier = try #require(UserDefaults(suiteName: suite))
        earlier.set("left by the last launch", forKey: "recentSearchQueries")
        defer { earlier.removePersistentDomain(forName: suite) }

        let store = AppDefaults.makeStore(.demo, suite: suite)

        #expect(store.object(forKey: "recentSearchQueries") == nil)
    }

    @Test func demoModeLeavesTheStandardStoreAlone() {
        let store = AppDefaults.makeStore(.demo, suite: suite)
        defer { store.removePersistentDomain(forName: suite) }
        let key = "demo.\(suite)"

        store.set(true, forKey: key)

        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }

    @Test func demoModeKeepsItsFilesOutOfTheAppsFolder() {
        let base = URL.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        #expect(AppDefaults.makeSupportDirectory(.demo, in: base) != AppDefaults.makeSupportDirectory(.app, in: base))
    }

    @Test func demoModeStartsFromAnEmptyFolder() throws {
        let base = URL.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let earlier = AppDefaults.makeSupportDirectory(.demo, in: base)
        try Data("left by the last launch".utf8).write(to: earlier.appendingPathComponent("image-url-cache.json"))

        let folder = AppDefaults.makeSupportDirectory(.demo, in: base)

        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    @Test func theAppKeepsItsFilesAcrossLaunches() throws {
        let base = URL.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let earlier = AppDefaults.makeSupportDirectory(.app, in: base)
        try Data("saved for a real speaker".utf8).write(to: earlier.appendingPathComponent("custom-artwork.json"))

        let folder = AppDefaults.makeSupportDirectory(.app, in: base)

        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["custom-artwork.json"])
    }
}
