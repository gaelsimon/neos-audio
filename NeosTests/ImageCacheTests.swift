import XCTest
import AppKit
@testable import Neos

/// Pins the split that keeps a scroll off the disk: the synchronous entry point is memory-only,
/// and only the async one is allowed to read and decode a file.
final class ImageCacheTests: XCTestCase {

    private func makeURL() -> URL {
        URL(string: "https://test.invalid/\(UUID().uuidString).png")!
    }

    private func makePNG() -> Data {
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor.orange.setFill()
            rect.fill()
            return true
        }
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return rep.representation(using: .png, properties: [:])!
    }

    /// The bug: `CachedAsyncImage.init` called a lookup that reached the disk, so every row
    /// scrolling in paid a stat, a full decode and an mtime write on the main thread.
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

    /// The other half: dropping the disk read from the fast path must not lose the cache.
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
