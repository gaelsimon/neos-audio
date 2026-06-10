import XCTest
@testable import Neos

final class ImageURLCacheTests: XCTestCase {
    private static let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Neos/image-url-cache.json")
    }()

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: Self.fileURL)
        ImageURLCache.resetCache()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        ImageURLCache.resetCache()
        super.tearDown()
    }

    func testEmptyByDefault() {
        XCTAssertTrue(ImageURLCache.all().isEmpty)
        XCTAssertNil(ImageURLCache.imageURL(forMID: "s12345"))
    }

    func testCacheAndRetrieve() {
        let added = ImageURLCache.cacheEntries([
            (mid: "s100", imageURL: "https://example.com/a.png"),
            (mid: "s200", imageURL: "https://example.com/b.png"),
        ])
        XCTAssertTrue(added)
        XCTAssertEqual(ImageURLCache.imageURL(forMID: "s100"), "https://example.com/a.png")
        XCTAssertEqual(ImageURLCache.imageURL(forMID: "s200"), "https://example.com/b.png")
        XCTAssertEqual(ImageURLCache.all().count, 2)
    }

    func testEmptyEntriesFiltered() {
        let added = ImageURLCache.cacheEntries([
            (mid: "", imageURL: "https://example.com/a.png"),
            (mid: "s100", imageURL: ""),
            (mid: "", imageURL: ""),
        ])
        XCTAssertFalse(added)
        XCTAssertTrue(ImageURLCache.all().isEmpty)
    }

    func testDuplicateEntryNotRewritten() {
        ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://example.com/a.png")])
        let changed = ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://example.com/a.png")])
        XCTAssertFalse(changed)
    }

    func testOverwriteEntry() {
        ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://old.com/a.png")])
        let changed = ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://new.com/a.png")])
        XCTAssertTrue(changed)
        XCTAssertEqual(ImageURLCache.imageURL(forMID: "s100"), "https://new.com/a.png")
    }

    func testMaxEntryCap() {
        // Fill the cache to the brim (5000 entries)
        var entries: [(mid: String, imageURL: String)] = []
        for i in 0..<5010 {
            entries.append((mid: "mid\(i)", imageURL: "https://example.com/\(i).png"))
        }
        ImageURLCache.cacheEntries(entries)

        let all = ImageURLCache.all()
        XCTAssertLessThanOrEqual(all.count, 5000)
    }

    func testPersistsToDisk() {
        ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://example.com/a.png")])

        XCTAssertTrue(FileManager.default.fileExists(atPath: Self.fileURL.path))

        let data = try! Data(contentsOf: Self.fileURL)
        let map = try! JSONDecoder().decode([String: String].self, from: data)
        XCTAssertEqual(map["s100"], "https://example.com/a.png")
    }

    func testInMemoryCacheAvoidsDiskReads() {
        // After initial load, subsequent reads should come from memory
        ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://example.com/a.png")])

        // Delete the file; reads should still work from memory
        try? FileManager.default.removeItem(at: Self.fileURL)

        XCTAssertEqual(ImageURLCache.imageURL(forMID: "s100"), "https://example.com/a.png")
    }

    func testResetCacheForcesReload() {
        ImageURLCache.cacheEntries([(mid: "s100", imageURL: "https://example.com/a.png")])
        ImageURLCache.resetCache()

        // After reset + file deletion, cache should be empty
        try? FileManager.default.removeItem(at: Self.fileURL)
        ImageURLCache.resetCache()
        XCTAssertTrue(ImageURLCache.all().isEmpty)
    }
}
