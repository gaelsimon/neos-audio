import Foundation
import Network
import os

/// Lightweight actor for controlling Marantz/Denon receivers via the AVR telnet protocol on port 23.
/// This is separate from the HEOS CLI protocol (port 1255); the AVR protocol uses simple ASCII
/// commands terminated by `\r` (not `\r\n` like HEOS).
///
/// Design: single-reader model. Only `receiveStream()` reads from the connection.
/// All commands are fire-and-forget via `send()`. Responses flow through the receive stream
/// and are routed by the caller (HEOSService's event listener).
public actor AVRControlClient {
    private var connection: NWConnection?
    private var receiveContinuation: AsyncThrowingStream<String, Error>.Continuation?
    private var buffer = Data()
    private static let delimiter = Data("\r".utf8)
    private static let maxBufferSize = 65_536  // 64 KB

    public var isConnected: Bool {
        connection?.state == .ready
    }

    public func connect(host: String, port: Int = 23) async throws {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)

        self.connection = conn

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw TransportError.timeout
            }
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let resumed = OSAllocatedUnfairLock(initialState: false)
                    conn.stateUpdateHandler = { state in
                        let shouldResume: Bool = resumed.withLock { val in
                            guard !val else { return false }
                            switch state {
                            case .ready, .failed, .cancelled:
                                val = true
                                return true
                            default:
                                return false
                            }
                        }
                        guard shouldResume else { return }
                        switch state {
                        case .ready:
                            continuation.resume()
                        case .failed(let error):
                            continuation.resume(throwing: error)
                        case .cancelled:
                            continuation.resume(throwing: TransportError.cancelled)
                        default:
                            break
                        }
                    }
                    conn.start(queue: DispatchQueue(label: "com.galela.neos.avr"))
                }
            }
            try await group.next()
            group.cancelAll()
        }

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed = state {
                Task { await self.handleDisconnection() }
            }
        }

        HEOSLogger.avr.info("Connected to AVR at \(host):\(port)")
    }

    public func disconnect() {
        receiveContinuation?.finish()
        receiveContinuation = nil
        connection?.cancel()
        connection = nil
        buffer = Data()
        HEOSLogger.avr.info("Disconnected from AVR")
    }

    /// Send a command (fire-and-forget). Response arrives via `receiveStream()`.
    public func send(_ command: String) async throws {
        guard let connection, isConnected else {
            throw TransportError.notConnected
        }

        let data = Data("\(command)\r".utf8)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        HEOSLogger.avr.debug("Sent: \(command)")
    }

    /// Returns an async stream of all incoming AVR messages.
    /// This is the sole reader on the connection; do not create multiple streams.
    nonisolated public func receiveStream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.startReceiving(continuation: continuation) }
        }
    }

    // MARK: - Power Commands (fire-and-forget)

    public func powerOn() async throws {
        try await send("PWON")
    }

    public func powerOff() async throws {
        try await send("PWSTANDBY")
    }

    /// Sends a power state query. The response ("PWON" or "PWSTANDBY") arrives via `receiveStream()`.
    public func queryPower() async throws {
        try await send("PW?")
    }

    // MARK: - Parsing

    /// Parses an AVR `MVMAX` response and converts to HEOS scale (0–100).
    /// Returns `nil` if the message is not an MVMAX response or is malformed.
    public static func parseMaxVolume(from message: String) -> Int? {
        guard message.hasPrefix("MVMAX ") else { return nil }
        let valueStr = message.dropFirst(6).prefix(2)
        guard let avrMax = Int(valueStr) else { return nil }
        let heosMax = Int(round(Double(avrMax) / 98.0 * 100.0))
        return min(heosMax, 100)
    }

    // MARK: - Private

    private func startReceiving(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.receiveContinuation = continuation
        scheduleRead()
    }

    private func scheduleRead() {
        guard let connection else {
            receiveContinuation?.finish(throwing: TransportError.notConnected)
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            Task { await self.handleReceivedData(data: data, isComplete: isComplete, error: error) }
        }
    }

    private func handleReceivedData(data: Data?, isComplete: Bool, error: NWError?) {
        if let error {
            receiveContinuation?.finish(throwing: error)
            return
        }

        if let data {
            if buffer.count + data.count > Self.maxBufferSize {
                buffer = Data()
                receiveContinuation?.finish(throwing: TransportError.bufferOverflow)
                return
            }
            buffer.append(data)
            emitCompleteMessages()
        }

        if isComplete {
            receiveContinuation?.finish()
        } else {
            scheduleRead()
        }
    }

    private func emitCompleteMessages() {
        while let range = buffer.range(of: Self.delimiter) {
            let messageData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            let message = String(decoding: messageData, as: UTF8.self)
                .trimmingCharacters(in: .newlines)  // Handle \r\n devices leaving stray \n
            if !message.isEmpty {
                receiveContinuation?.yield(message)
            }
        }
    }

    private func handleDisconnection() {
        receiveContinuation?.finish(throwing: TransportError.disconnected)
        receiveContinuation = nil
        connection = nil
        buffer = Data()
        HEOSLogger.avr.warning("AVR connection lost")
    }
}
