import Foundation
import Testing
@testable import Neos

struct AppDefaultsTests {
    private let suite = "com.galela.neos.tests.\(UUID().uuidString)"

    @Test func theAppKeepsItsSettingsInTheStandardStore() {
        #expect(AppDefaults.makeStore(demo: false) === UserDefaults.standard)
    }

    @Test func theTestsRunOnTheStandardStore() {
        #expect(AppDefaults.store === UserDefaults.standard)
    }

    @Test func demoModeStartsFromAnEmptyStore() throws {
        let earlier = try #require(UserDefaults(suiteName: suite))
        earlier.set("left by the last launch", forKey: "recentSearchQueries")
        defer { earlier.removePersistentDomain(forName: suite) }

        let store = AppDefaults.makeStore(demo: true, suite: suite)

        #expect(store.object(forKey: "recentSearchQueries") == nil)
    }

    @Test func demoModeLeavesTheStandardStoreAlone() {
        let store = AppDefaults.makeStore(demo: true, suite: suite)
        defer { store.removePersistentDomain(forName: suite) }
        let key = "demo.\(suite)"

        store.set(true, forKey: key)

        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }
}
