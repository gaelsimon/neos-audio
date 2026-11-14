import XCTest
@testable import Neos

/// The synchronous lookup stays in memory; only the async one may read and decode a file.
final class ImageCacheTests: XCTestCase {

    private func makeURL() -> URL {
        URL(string: "https://test.invalid/\(UUID().uuidString).png")!
    }

    private func makePNG() -> Data {
        TestImages.png()
    }

    func testMemoryOnlyDoesNotReachTheDisk() async {
        let url = makeURL()
        let stored = await ImageCache.shared.store(makePNG(), for: url)
        XCTAssertNotNil(stored, "store must decode and cache the image")
        XCTAssertNotNil(ImageCache.shared.memoryOnly(url), "still in memory right after storing")

        ImageCache.shared.clearMemory()

        // The file is still on disk, but the synchronous path must refuse to go and get it.
        XCTAssertNil(
            ImageCache.shared.memoryOnly(url),
            "memoryOnly reached the disk; that is the main-thread stall this split exists to prevent"
        )
    }

    func testLoadStillFindsTheFileAfterMemoryIsDropped() async {
        let url = makeURL()
        _ = await ImageCache.shared.store(makePNG(), for: url)
        ImageCache.shared.clearMemory()

        let fromDisk = await ImageCache.shared.load(url)

        XCTAssertNotNil(fromDisk, "load must still read the file the fast path declined to touch")
        XCTAssertNotNil(ImageCache.shared.memoryOnly(url), "a disk hit repopulates memory")
    }

    func testLoadReturnsNilForSomethingNeverCached() async {
        let image = await ImageCache.shared.load(makeURL())
        XCTAssertNil(image)
    }

    /// `skipDisk` is used for file:// URLs, which are already on disk.
    func testSkipDiskCachesInMemoryOnly() async {
        let url = makeURL()
        _ = await ImageCache.shared.store(makePNG(), for: url, skipDisk: true)
        XCTAssertNotNil(ImageCache.shared.memoryOnly(url))

        ImageCache.shared.clearMemory()

        let fromDisk = await ImageCache.shared.load(url)
        XCTAssertNil(fromDisk, "nothing should have been written")
    }
}
