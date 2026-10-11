import Foundation

/// Asks GitHub for the latest release once a day and reports it when it is newer than this build.
struct UpdateChecker {
    struct Update: Equatable {
        let version: String
        let url: URL
    }

    struct Version: Comparable, CustomStringConvertible {
        let numbers: [Int]
        let suffix: String

        init?(_ text: String) {
            var body = text.hasPrefix("v") ? String(text.dropFirst()) : text
            var suffix = ""
            if let dash = body.firstIndex(of: "-") {
                suffix = String(body[body.index(after: dash)...])
                body = String(body[..<dash])
            }
            let numbers = body.split(separator: ".").map { Int($0) }
            guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
            self.numbers = numbers.compactMap { $0 }
            self.suffix = suffix
        }

        var description: String {
            let base = numbers.map(String.init).joined(separator: ".")
            return suffix.isEmpty ? base : "\(base)-\(suffix)"
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            let count = max(lhs.numbers.count, rhs.numbers.count)
            for i in 0..<count {
                let l = i < lhs.numbers.count ? lhs.numbers[i] : 0
                let r = i < rhs.numbers.count ? rhs.numbers[i] : 0
                if l != r { return l < r }
            }
            // A release outranks its own prereleases: 1.5.0-beta < 1.5.0.
            if lhs.suffix.isEmpty != rhs.suffix.isEmpty { return !lhs.suffix.isEmpty }
            return lhs.suffix < rhs.suffix
        }
    }

    struct Release: Decodable {
        let tagName: String
        let htmlUrl: URL
        let draft: Bool
        let prerelease: Bool
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/gaelsimon/neos-audio/releases/latest")
    static let interval: TimeInterval = 24 * 60 * 60
    static let lastCheckKey = "update.lastCheck"
    static let knownVersionKey = "update.knownVersion"
    static let knownURLKey = "update.knownURL"
    static let notifiedVersionKey = "update.notifiedVersion"

    let currentVersion: String
    let defaults: UserDefaults
    let fetch: @Sendable (URL) async -> Data?
    let now: () -> Date

    init(currentVersion: String, defaults: UserDefaults = .standard,
         fetch: @escaping @Sendable (URL) async -> Data? = Self.fetchFromGitHub, now: @escaping () -> Date = Date.init) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.fetch = fetch
        self.now = now
    }

    /// The newest release when it beats this build; between two checks, the one found last time.
    func check() async -> Update? {
        // Builds straight from the repo carry a -dev suffix and never want to be told about a release.
        guard let current = Version(currentVersion), current.suffix != "dev" else { return nil }
        if let last = defaults.object(forKey: Self.lastCheckKey) as? Date, now().timeIntervalSince(last) < Self.interval {
            return known(newerThan: current)
        }
        guard let endpoint = Self.latestReleaseURL, let data = await fetch(endpoint) else { return nil }
        defaults.set(now(), forKey: Self.lastCheckKey)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let release = try? decoder.decode(Release.self, from: data), !release.draft, !release.prerelease,
              let latest = Version(release.tagName), current < latest else {
            defaults.removeObject(forKey: Self.knownVersionKey)
            defaults.removeObject(forKey: Self.knownURLKey)
            return nil
        }
        defaults.set(latest.description, forKey: Self.knownVersionKey)
        defaults.set(release.htmlUrl.absoluteString, forKey: Self.knownURLKey)
        return Update(version: latest.description, url: release.htmlUrl)
    }

    /// True the first time a given version is reported, so the toast shows once and the About row stays.
    func markNotified(_ update: Update) -> Bool {
        guard defaults.string(forKey: Self.notifiedVersionKey) != update.version else { return false }
        defaults.set(update.version, forKey: Self.notifiedVersionKey)
        return true
    }

    private func known(newerThan current: Version) -> Update? {
        guard let text = defaults.string(forKey: Self.knownVersionKey), let version = Version(text), current < version,
              let urlText = defaults.string(forKey: Self.knownURLKey), let url = URL(string: urlText) else { return nil }
        return Update(version: version.description, url: url)
    }

    @Sendable static func fetchFromGitHub(_ url: URL) async -> Data? {
        guard let result = try? await NeosURLSession.shared.data(from: url),
              let http = result.1 as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return result.0
    }
}
