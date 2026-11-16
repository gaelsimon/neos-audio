import SwiftUI
import CommonCrypto

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let highResURL: URL?
    let placeholder: () -> Placeholder

    @State private var image: PlatformImage?
    @State private var loadedURL: URL?

    init(url: URL?, highResURL: URL? = nil, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.highResURL = highResURL
        self.placeholder = placeholder
        // Memory only: `init` runs for every row scrolling in, and the disk would stall the main thread.
        if let highResURL, let cached = ImageCache.shared.memoryOnly(highResURL) {
            _image = State(initialValue: cached)
            _loadedURL = State(initialValue: highResURL)
        } else if let url, let cached = ImageCache.shared.memoryOnly(url) {
            _image = State(initialValue: cached)
            _loadedURL = State(initialValue: url)
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .onChange(of: url) {
            // Immediately clear stale image when URL changes to prevent showing wrong artwork
            guard url != loadedURL else { return }
            if let url, let cached = ImageCache.shared.memoryOnly(url) {
                self.image = cached
                self.loadedURL = url
            } else if let highResURL, let cached = ImageCache.shared.memoryOnly(highResURL) {
                self.image = cached
                self.loadedURL = highResURL
            } else {
                self.image = nil
                self.loadedURL = nil
            }
        }
        .task(id: url) {
            guard let url else { self.image = nil; loadedURL = nil; return }
            // Already showing the best version from memory: nothing to read or fetch.
            if image != nil, loadedURL == (highResURL ?? url) { return }
            let lowResShown = image != nil && loadedURL == url

            if let highResURL, let cached = await ImageCache.shared.load(highResURL) {
                guard !Task.isCancelled else { return }
                self.image = cached
                self.loadedURL = highResURL
                return
            }
            if !lowResShown, let cached = await ImageCache.shared.load(url) {
                guard !Task.isCancelled else { return }
                self.image = cached
                self.loadedURL = url
            } else if !lowResShown, loadedURL != url {
                self.image = nil
                self.loadedURL = nil
                do {
                    let data = try await Self.fetch(url)
                    guard !Task.isCancelled else { return }
                    if let decoded = await ImageCache.shared.store(data, for: url, skipDisk: url.isFileURL) {
                        guard !Task.isCancelled else { return }
                        self.image = decoded
                        self.loadedURL = url
                    }
                } catch {
                    // Silently fail - placeholder remains visible
                }
            }

            // Progressive upgrade: silently fetch high-res version
            if let highResURL, highResURL != url, loadedURL != highResURL {
                do {
                    let data = try await Self.fetch(highResURL)
                    guard !Task.isCancelled else { return }
                    if let decoded = await ImageCache.shared.store(
                        data, for: highResURL, skipDisk: highResURL.isFileURL
                    ) {
                        guard !Task.isCancelled else { return }
                        self.image = decoded
                        self.loadedURL = highResURL
                    }
                } catch {
                    // Non-fatal; primary image remains
                }
            }
        }
    }

    private static func fetch(_ url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        let (data, _) = try await NeosURLSession.shared.data(from: url)
        return data
    }
}

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, PlatformImage>()
    private let diskURL: URL
    private let maxDiskBytes: Int = 100 * 1024 * 1024 // 100 MB
    private let queue = DispatchQueue(label: "com.galela.neos.imagecache", qos: .utility)
    /// Sweeping the whole cache directory on every write made a scroll pay for its own eviction.
    private let evictionInterval = 32
    private var writesSinceEviction = 0

    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        diskURL = AppDefaults.supportDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    /// Non-blocking lookup. The only variant safe to call while a list is scrolling.
    func memoryOnly(_ url: URL) -> PlatformImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// Memory, then disk. The disk read and the decode run off the caller's thread.
    func load(_ url: URL) async -> PlatformImage? {
        if let cached = memoryOnly(url) { return cached }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: readFromDisk(url))
            }
        }
    }

    /// Decodes downloaded bytes off the caller's thread, then caches them.
    func store(_ data: Data, for url: URL, skipDisk: Bool = false) async -> PlatformImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard let image = Self.decodeImage(from: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                insertInMemory(image, for: url)
                if !skipDisk { writeToDisk(data, for: url) }
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Private

    private func insertInMemory(_ image: PlatformImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    private func readFromDisk(_ url: URL) -> PlatformImage? {
        let file = Self.diskPath(for: url, in: diskURL)
        guard let data = try? Data(contentsOf: file),
              let image = Self.decodeImage(from: data) else { return nil }
        // Touch access date for LRU
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        insertInMemory(image, for: url)
        return image
    }

    private func writeToDisk(_ data: Data, for url: URL) {
        try? data.write(to: Self.diskPath(for: url, in: diskURL), options: .atomic)
        writesSinceEviction += 1
        guard writesSinceEviction >= evictionInterval else { return }
        writesSinceEviction = 0
        Self.evictIfNeeded(in: diskURL, maxBytes: maxDiskBytes)
    }

    // MARK: - Cache Management

    /// Total size of the disk cache in bytes.
    func diskSizeBytes() -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diskURL, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return files.reduce(0) { total, fileURL in
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + size
        }
    }

    /// Drops the decoded bitmaps but keeps the files, which is also what memory pressure does.
    func clearMemory() {
        memoryCache.removeAllObjects()
    }

    /// Clear memory and disk caches entirely.
    func clearAll() {
        memoryCache.removeAllObjects()
        queue.async { [diskURL] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(at: diskURL, includingPropertiesForKeys: nil) else { return }
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
    }

    // MARK: - Decoding

    /// Redrawn into 32-bpp RGBA: 24-bpp JPEGs crash CoreGraphics while rendering (rdar://143602439).
    static func decodeImage(from data: Data) -> PlatformImage? {
        guard let source = PlatformImage(data: data), let cgImage = source.cgImageValue else {
            return nil
        }
        let w = cgImage.width
        let h = cgImage.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return source
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let safe = ctx.makeImage() else { return source }
        return PlatformImage(cgImage: safe, pixelSize: CGSize(width: w, height: h))
    }

    // MARK: - Disk Helpers

    private static func diskPath(for url: URL, in directory: URL) -> URL {
        let hash = sha256Hex(url.absoluteString)
        return directory.appendingPathComponent(hash + ".png")
    }

    private static func sha256Hex(_ string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func evictIfNeeded(in directory: URL, maxBytes: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }

        var entries: [(url: URL, size: Int, date: Date)] = files.compactMap { fileURL in
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let date = values.contentModificationDate else { return nil }
            return (fileURL, size, date)
        }

        let totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > maxBytes else { return }

        // Evict oldest first until under 80% of max
        let target = maxBytes * 80 / 100
        entries.sort { $0.date < $1.date }
        var freed = totalSize
        for entry in entries {
            guard freed > target else { break }
            try? fm.removeItem(at: entry.url)
            freed -= entry.size
        }
    }
}
