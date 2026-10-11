import Foundation
import Testing
@testable import Neos

@Suite("UpdateChecker Tests")
struct UpdateCheckerTests {
    private let defaults: UserDefaults
    private let suiteName = "UpdateCheckerTests.\(UUID().uuidString)"

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func release(_ tag: String, draft: Bool = false, prerelease: Bool = false) -> Data {
        let json: [String: Any] = [
            "tag_name": tag,
            "html_url": "https://github.com/gaelsimon/neos-audio/releases/tag/\(tag)",
            "draft": draft,
            "prerelease": prerelease
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func checker(current: String, serving data: Data?, now: Date = Date(), calls: Counter? = nil) -> UpdateChecker {
        UpdateChecker(currentVersion: current, defaults: defaults, fetch: { _ in
            calls?.increment()
            return data
        }, now: { now })
    }

    final class Counter: @unchecked Sendable {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    // MARK: - Versions

    @Test func versionParsesTagsWithAndWithoutPrefixOrSuffix() {
        #expect(UpdateChecker.Version("v1.4.1")?.numbers == [1, 4, 1])
        #expect(UpdateChecker.Version("1.4")?.numbers == [1, 4])
        #expect(UpdateChecker.Version("1.5.0-beta.1")?.suffix == "beta.1")
        #expect(UpdateChecker.Version("latest") == nil)
        #expect(UpdateChecker.Version("") == nil)
    }

    @Test func versionsCompareNumericallyThenByPrerelease() {
        let v = { UpdateChecker.Version($0)! }
        #expect(v("1.4.1") < v("1.5.0"))
        #expect(v("1.10.0") > v("1.9.9"))
        #expect(v("1.4") < v("1.4.1"))
        #expect(v("1.5.0-beta") < v("1.5.0"))
        #expect(v("1.5.0-alpha") < v("1.5.0-beta"))
        #expect(!(v("1.4.1") < v("v1.4.1")))
    }

    @Test func versionDescriptionDropsThePrefix() {
        #expect(UpdateChecker.Version("v1.4.1")?.description == "1.4.1")
        #expect(UpdateChecker.Version("1.5.0-beta")?.description == "1.5.0-beta")
    }

    // MARK: - Check

    @Test func newerReleaseIsReported() async {
        let update = await checker(current: "1.4.1", serving: release("v1.5.0")).check()
        #expect(update?.version == "1.5.0")
        #expect(update?.url.absoluteString == "https://github.com/gaelsimon/neos-audio/releases/tag/v1.5.0")
    }

    @Test func sameOrOlderReleaseIsNotReported() async {
        #expect(await checker(current: "1.5.0", serving: release("v1.5.0")).check() == nil)
        #expect(await checker(current: "1.5.1", serving: release("v1.5.0")).check() == nil)
    }

    @Test func draftsAndPrereleasesAreIgnored() async {
        #expect(await checker(current: "1.4.1", serving: release("v1.5.0", draft: true)).check() == nil)
        #expect(await checker(current: "1.4.1", serving: release("v1.5.0", prerelease: true)).check() == nil)
    }

    @Test func prereleaseBuildIsToldAboutItsRelease() async {
        let update = await checker(current: "1.5.0-beta", serving: release("v1.5.0")).check()
        #expect(update?.version == "1.5.0")
    }

    @Test func devBuildsNeverCheck() async {
        let calls = Counter()
        #expect(await checker(current: "1.3.0-dev", serving: release("v9.0.0"), calls: calls).check() == nil)
        #expect(calls.count == 0)
    }

    @Test func failedFetchAndBadJSONReportNothing() async {
        #expect(await checker(current: "1.4.1", serving: nil).check() == nil)
        #expect(await checker(current: "1.4.1", serving: Data("nope".utf8)).check() == nil)
    }

    @Test func checksAtMostOncePerDayAndRemembersTheUpdate() async {
        let start = Date()
        let calls = Counter()
        let first = await checker(current: "1.4.1", serving: release("v1.5.0"), now: start, calls: calls).check()
        let later = await checker(current: "1.4.1", serving: nil, now: start.addingTimeInterval(3600), calls: calls).check()
        let nextDay = await checker(current: "1.4.1", serving: release("v1.6.0"), now: start.addingTimeInterval(90_000), calls: calls).check()
        #expect(first?.version == "1.5.0")
        #expect(later == first)
        #expect(nextDay?.version == "1.6.0")
        #expect(calls.count == 2)
    }

    @Test func rememberedUpdateIsDroppedOnceInstalled() async {
        let start = Date()
        _ = await checker(current: "1.4.1", serving: release("v1.5.0"), now: start).check()
        let afterUpdate = await checker(current: "1.5.0", serving: nil, now: start.addingTimeInterval(60)).check()
        #expect(afterUpdate == nil)
    }

    @Test func olderReleaseForgetsARememberedUpdate() async {
        let start = Date()
        _ = await checker(current: "1.4.1", serving: release("v1.5.0"), now: start).check()
        _ = await checker(current: "1.4.1", serving: release("v1.4.1"), now: start.addingTimeInterval(90_000)).check()
        let throttled = await checker(current: "1.4.1", serving: nil, now: start.addingTimeInterval(90_060)).check()
        #expect(throttled == nil)
    }

    // MARK: - Notification

    @Test func eachVersionIsNotifiedOnce() {
        let checker = checker(current: "1.4.1", serving: nil)
        let update = UpdateChecker.Update(version: "1.5.0", url: URL(string: "https://example.com")!)
        let next = UpdateChecker.Update(version: "1.6.0", url: URL(string: "https://example.com")!)
        #expect(checker.markNotified(update))
        #expect(!checker.markNotified(update))
        #expect(checker.markNotified(next))
    }
}
