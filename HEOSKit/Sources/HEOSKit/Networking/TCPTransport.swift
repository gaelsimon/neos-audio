import Foundation
import Network
import os

public actor TCPTransport: TransportProtocol {
    private var connection: NWConnection?
    private var receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var buffer = Data()
    private static let delimiter = Data("\r\n".utf8)
    private static let maxBufferSize = 1_048_576  // 1 MB

    public init() {}

    public var isConnected: Bool {
        connection?.state == .ready
    }

    public func connect(host: String, port: Int) async throws {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))

        let conn = NWConnection(host: nwHost, port: nwPort, using: NWParameters.tcp)

        self.connection = conn

        try await awaitConnection(conn)

        // Clear the state handler after connection is established
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed = state {
                Task { await self.handleDisconnection() }
            }
        }
    }

    /// Races a 10-second timeout against the connection reaching a terminal state.
    private func awaitConnection(_ conn: NWConnection) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw TransportError.timeout
            }
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let resumed = OSAllocatedUnfairLock(initialState: false)
                    conn.stateUpdateHandler = { state in
                        switch state {
                        case .ready, .failed, .cancelled, .waiting:
                            let shouldResume = resumed.withLock { val -> Bool in
                                guard !val else { return false }
                                val = true
                                return true
                            }
                            guard shouldResume else { return }
                            switch state {
                            case .ready:
                                continuation.resume()
                            case .failed(let error):
                                continuation.resume(throwing: error)
                            case .cancelled:
                                continuation.resume(throwing: TransportError.cancelled)
                            case .waiting(let error):
                                continuation.resume(throwing: error)
                            default:
                                break
                            }
                        default:
                            break  // Ignore intermediate states (.preparing, .setup)
                        }
                    }
                    conn.start(queue: DispatchQueue(label: "com.galela.neos.tcp"))
                }
            }
            // First task to finish wins; cancel the other
            try await group.next()
            group.cancelAll()
        }
    }

    public func disconnect() async {
        receiveContinuation?.finish()
        receiveContinuation = nil
        connection?.cancel()
        connection = nil
        buffer = Data()
    }

    public func send(_ data: Data) async throws {
        guard let connection, isConnected else {
            throw TransportError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    nonisolated public func receive() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.startReceiving(continuation: continuation) }
        }
    }

    private func startReceiving(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
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
            receiveContinuation?.yield(messageData)
        }
    }

    private func handleDisconnection() {
        receiveContinuation?.finish(throwing: TransportError.disconnected)
        receiveContinuation = nil
        connection = nil
        buffer = Data()
    }
}

public enum TransportError: Error, Sendable {
    case notConnected
    case cancelled
    case disconnected
    case timeout
    case bufferOverflow
}
