import Foundation

/// A URLProtocol subclass that intercepts HTTP requests and returns canned responses.
/// Uses path-based dispatch so multiple test suites can register handlers concurrently.
final class MockURLProtocol: URLProtocol {
    /// Map of URL path substring → handler closure, guarded by `lock` for concurrent test suites.
    nonisolated(unsafe) private static var handlers: [String: (URLRequest) -> (Int, String)] = [:]
    private static let lock = NSLock()

    /// Register a handler for requests whose URL path contains the given substring.
    static func register(pathContaining path: String, handler: @escaping (URLRequest) -> (Int, String)) {
        lock.lock()
        defer { lock.unlock() }
        handlers[path] = handler
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
    }

    /// Look up the handler matching the given path under the lock.
    private static func handler(for path: String) -> ((URLRequest) -> (Int, String))? {
        lock.lock()
        defer { lock.unlock() }
        return handlers.first { path.contains($0.key) }?.value
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let handler = Self.handler(for: path)
        let (statusCode, body) = handler?(request) ?? (404, "")

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/xml"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// Create a URLSessionConfiguration with this mock protocol registered.
    static func makeConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }
}
