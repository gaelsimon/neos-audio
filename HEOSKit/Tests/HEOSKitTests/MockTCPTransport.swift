@testable import HEOSKit
import Foundation

actor MockTCPTransport: TransportProtocol {
    var isConnected: Bool = false
    private(set) var sentData: [Data] = []
    private(set) var connectedHost: String?
    private(set) var connectedPort: Int?

    private var responseContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var responses: [Data] = []

    /// When true, queued responses are delivered immediately on `send()`.
    /// When false, responses accumulate and must be delivered manually via `deliverNextResponse()`.
    var autoRespond: Bool

    init(autoRespond: Bool = true) {
        self.autoRespond = autoRespond
    }

    func connect(host: String, port: Int) async throws {
        connectedHost = host
        connectedPort = port
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        responseContinuation?.finish()
        responseContinuation = nil
    }

    func send(_ data: Data) async throws {
        guard isConnected else { throw TransportError.notConnected }
        sentData.append(data)

        if autoRespond && !responses.isEmpty {
            let response = responses.removeFirst()
            responseContinuation?.yield(response)
        }
    }

    nonisolated func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.setResponseContinuation(continuation) }
        }
    }

    private func setResponseContinuation(_ continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.responseContinuation = continuation
    }

    // MARK: - Test Helpers

    func enqueueResponse(_ json: String) {
        responses.append(Data(json.utf8))
    }

    /// Deliver the next queued response (for manual-respond mode).
    /// Returns true if a response was delivered, false if the queue was empty.
    @discardableResult
    func deliverNextResponse() -> Bool {
        guard !responses.isEmpty else { return false }
        let response = responses.removeFirst()
        responseContinuation?.yield(response)
        return true
    }

    func simulateEvent(_ json: String) {
        responseContinuation?.yield(Data(json.utf8))
    }

    func simulateDisconnection() {
        responseContinuation?.finish(throwing: TransportError.disconnected)
        responseContinuation = nil
        isConnected = false
    }

    func lastSentString() -> String? {
        guard let data = sentData.last else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func reset() {
        sentData = []
        responses = []
    }
}
