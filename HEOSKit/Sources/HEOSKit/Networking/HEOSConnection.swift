import Foundation
import os

public actor HEOSConnection {
    private let transport: any TransportProtocol
    private let commandBuilder = HEOSCommandBuilder()
    private let responseParser = HEOSResponseParser()
    private var eventContinuation: AsyncStream<HEOSEvent>.Continuation?

    private struct PendingCommand {
        let id: UInt64
        let commandKey: String
        let continuation: CheckedContinuation<HEOSResponse, Error>
        let timeoutTask: Task<Void, Never>
        let timeoutDuration: Duration
    }

    private var nextCommandID: UInt64 = 0
    private var pendingCommands: [UInt64: PendingCommand] = [:]
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    public init(transport: any TransportProtocol) {
        self.transport = transport
    }

    public var isConnected: Bool {
        get async { await transport.isConnected }
    }

    public func connect(host: String, port: Int) async throws {
        HEOSLogger.connection.info("Connecting to \(host):\(port)")
        try await transport.connect(host: host, port: port)
        HEOSLogger.connection.info("Connected to \(host):\(port)")
        startReceiving()
    }

    public func disconnect() async {
        HEOSLogger.connection.info("Disconnecting")
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil

        for (_, pending) in pendingCommands {
            pending.timeoutTask.cancel()
            pending.continuation.resume(throwing: TransportError.disconnected)
        }
        pendingCommands.removeAll()

        eventContinuation?.finish()
        eventContinuation = nil

        await transport.disconnect()
        HEOSLogger.connection.info("Disconnected")
    }

    @discardableResult
    public func send(_ command: HEOSCommand, timeout: Duration = .seconds(15)) async throws -> HEOSResponse {
        let commandString = commandBuilder.build(command)
        let commandKey = Self.matchingKey(for: command)

        let id = nextCommandID
        nextCommandID &+= 1

        let data = Data(commandString.utf8)
        try await transport.send(data)

        HEOSLogger.connection.debug("Sent command #\(id): \(commandString.trimmingCharacters(in: .whitespacesAndNewlines))")

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                if let timedOut = pendingCommands.removeValue(forKey: id) {
                    HEOSLogger.connection.warning("Command #\(id) timed out: \(commandKey)")
                    timedOut.continuation.resume(throwing: TransportError.timeout)
                }
            }
            let pending = PendingCommand(id: id, commandKey: commandKey, continuation: continuation, timeoutTask: timeoutTask, timeoutDuration: timeout)
            pendingCommands[id] = pending
        }
    }

    public func sendFireAndForget(_ command: HEOSCommand) async throws {
        let commandString = commandBuilder.build(command)
        let data = Data(commandString.utf8)
        try await transport.send(data)
    }

    public func makeEventStream() -> AsyncStream<HEOSEvent> {
        let (stream, continuation) = AsyncStream<HEOSEvent>.makeStream()
        self.eventContinuation = continuation
        return stream
    }

    public func startHeartbeat(interval: TimeInterval = 10.0) {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            var consecutiveFailures = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                do {
                    try await send(.heartBeat, timeout: .seconds(5))
                    consecutiveFailures = 0
                } catch {
                    consecutiveFailures += 1
                    HEOSLogger.connection.warning("Heartbeat failed (\(consecutiveFailures)/3): \(error.localizedDescription)")
                    if consecutiveFailures >= 3 {
                        HEOSLogger.connection.error("3 consecutive heartbeat failures; connection lost")
                        handleReceiveError(TransportError.disconnected)
                        break
                    }
                }
            }
        }
    }

    // MARK: - Private

    private func startReceiving() {
        receiveTask = Task {
            let stream = transport.receive()
            do {
                for try await data in stream {
                    handleMessage(data)
                }
            } catch {
                handleReceiveError(error)
            }
        }
    }

    private func handleMessage(_ data: Data) {
        do {
            let parsed = try responseParser.parse(data)
            switch parsed {
            case .response(let response):
                let commandKey = Self.responseMatchingKey(for: response)
                if response.isUnderProcess {
                    HEOSLogger.connection.debug("Command under process for \(response.command), waiting for real response")
                    resetTimeout(for: commandKey)
                } else if let id = oldestPendingID(for: commandKey),
                          let pending = pendingCommands.removeValue(forKey: id) {
                    HEOSLogger.connection.debug("Matched response #\(id): \(response.command)")
                    pending.timeoutTask.cancel()
                    pending.continuation.resume(returning: response)
                } else {
                    HEOSLogger.connection.warning("Unmatched response: \(commandKey) (pending: \(self.pendingCommandKeys))")
                }
            case .event(let event):
                if event.eventName.contains("error") {
                    HEOSLogger.connection.warning("Event: \(event.eventName); \(event.message)")
                } else {
                    HEOSLogger.connection.debug("Event: \(event.eventName)")
                }
                eventContinuation?.yield(event)
            }
        } catch {
            if let heosError = error as? HEOSError {
                let commandKey = Self.errorMatchingKey(for: heosError)
                let matchID = oldestPendingID(for: commandKey)
                    ?? oldestPendingIDByPrefix(for: heosError.command)
                if let id = matchID,
                   let pending = pendingCommands.removeValue(forKey: id) {
                    pending.timeoutTask.cancel()
                    pending.continuation.resume(throwing: heosError)
                } else {
                    HEOSLogger.connection.warning("Unmatched error response: \(commandKey)")
                    eventContinuation?.yield(HEOSEvent(
                        command: "event/system_error",
                        message: [
                            "command": commandKey,
                            "error": heosError.text,
                            "eid": "\(heosError.errorID)"
                        ]
                    ))
                }
            } else {
                let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                HEOSLogger.connection.error("Parse error: \(error.localizedDescription); data: \(preview)")
            }
        }
    }

    private func handleReceiveError(_ error: Error) {
        HEOSLogger.connection.error("Receive error: \(error.localizedDescription)")
        for (_, pending) in pendingCommands {
            pending.timeoutTask.cancel()
            pending.continuation.resume(throwing: error)
        }
        pendingCommands.removeAll()
        eventContinuation?.finish()
    }

    /// Find the oldest pending command ID matching a command key (FIFO).
    private func oldestPendingID(for commandKey: String) -> UInt64? {
        pendingCommands.values
            .filter { $0.commandKey == commandKey }
            .min(by: { $0.id < $1.id })?
            .id
    }

    /// Fallback: find the oldest pending command whose key starts with the given
    /// command prefix. Used when error responses omit parameters (e.g. HEOS returns
    /// "browse/browse" error without sid, but we have "browse/browse|sid=13" pending).
    private func oldestPendingIDByPrefix(for command: String) -> UInt64? {
        pendingCommands.values
            .filter { $0.commandKey.hasPrefix(command) }
            .min(by: { $0.id < $1.id })?
            .id
    }

    /// Reset the timeout for a pending command when the device sends "command under process".
    private func resetTimeout(for commandKey: String) {
        guard let id = oldestPendingID(for: commandKey),
              let existing = pendingCommands.removeValue(forKey: id) else { return }
        existing.timeoutTask.cancel()
        let duration = existing.timeoutDuration
        let newTimeoutTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            if let timedOut = pendingCommands.removeValue(forKey: id) {
                HEOSLogger.connection.warning("Command #\(id) timed out: \(commandKey)")
                timedOut.continuation.resume(throwing: TransportError.timeout)
            }
        }
        pendingCommands[id] = PendingCommand(
            id: existing.id,
            commandKey: existing.commandKey,
            continuation: existing.continuation,
            timeoutTask: newTimeoutTask,
            timeoutDuration: duration
        )
    }

    private var pendingCommandKeys: String {
        pendingCommands.values
            .sorted(by: { $0.id < $1.id })
            .map { "#\($0.id):\($0.commandKey)" }
            .joined(separator: ", ")
    }

    // MARK: - Response Matching

    /// Builds a matching key from a command. For browse commands, includes the SID
    /// (and CID when present) so responses are routed to the correct caller.
    /// Without CID in the key, a concurrent `browseSource(sid: X)` and
    /// `browseSourceContainer(sid: X, cid: Y)` share a FIFO queue, and
    /// out-of-order responses (e.g. after "command under process") get swapped.
    /// CIDs are normalized via percent-decoding because the device echoes them
    /// decoded even when they were sent encoded (e.g. TuneIn URL-based CIDs).
    private static func matchingKey(for command: HEOSCommand) -> String {
        switch command {
        case .browseSource(let sid, _):
            return "browse/browse|sid=\(sid)"
        case .browseSourceContainer(let sid, let cid, _):
            return "browse/browse|sid=\(sid)&cid=\(normalizeCID(cid))"
        case .search(let sid, _, let scid, _):
            return "browse/search|sid=\(sid)&scid=\(scid)"
        case .getSearchCriteria(let sid):
            return "browse/get_search_criteria|sid=\(sid)"
        default:
            return command.commandPath
        }
    }

    /// Reconstructs the matching key from a response by extracting SID (and CID
    /// when present) from the message parameters. Mirrors `matchingKey(for:)`.
    private static func responseMatchingKey(for response: HEOSResponse) -> String {
        if let sid = response.message["sid"] {
            switch response.command {
            case "browse/browse":
                if let cid = response.message["cid"] {
                    return "browse/browse|sid=\(sid)&cid=\(normalizeCID(cid))"
                }
                return "browse/browse|sid=\(sid)"
            case "browse/search":
                if let scid = response.message["scid"] {
                    return "browse/search|sid=\(sid)&scid=\(scid)"
                }
                return "browse/search|sid=\(sid)"
            case "browse/get_search_criteria":
                return "browse/get_search_criteria|sid=\(sid)"
            default:
                break
            }
        }
        return response.command
    }

    /// Reconstructs the matching key from an error response.
    private static func errorMatchingKey(for error: HEOSError) -> String {
        if let sid = error.message["sid"] {
            switch error.command {
            case "browse/browse":
                if let cid = error.message["cid"] {
                    return "browse/browse|sid=\(sid)&cid=\(normalizeCID(cid))"
                }
                return "browse/browse|sid=\(sid)"
            case "browse/search":
                if let scid = error.message["scid"] {
                    return "browse/search|sid=\(sid)&scid=\(scid)"
                }
                return "browse/search|sid=\(sid)"
            case "browse/get_search_criteria":
                return "browse/get_search_criteria|sid=\(sid)"
            default:
                break
            }
        }
        return error.command
    }

    /// Fully percent-decodes a CID for matching key normalization.
    /// HEOS browse responses echo CIDs fully decoded even when sent with nested
    /// encoding (e.g. `%252C` → `%2C` → `,`). Decode repeatedly until stable.
    private static func normalizeCID(_ cid: String) -> String {
        var result = cid
        while let decoded = result.removingPercentEncoding, decoded != result {
            result = decoded
        }
        return result
    }
}
