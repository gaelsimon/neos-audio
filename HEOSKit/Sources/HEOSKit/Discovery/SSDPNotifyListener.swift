import Foundation
import os

#if canImport(Darwin)
import Darwin
#endif

public actor SSDPNotifyListener {
    private static let multicastAddress = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900
    private static let heosNotificationType = "urn:schemas-denon-com:device:ACT-Denon:1"
    private static let pollIntervalMs: Int32 = 200

    private var socketFD: Int32 = -1
    private var isRunning = false

    public init() {}

    public func listen() -> AsyncStream<SSDPResponse> {
        let (stream, continuation) = AsyncStream<SSDPResponse>.makeStream()

        guard !isRunning else { return stream }
        isRunning = true

        let fd: Int32
        do {
            fd = try Self.createMulticastSocket()
        } catch {
            HEOSLogger.discovery.error("Failed to create NOTIFY listener socket: \(error.localizedDescription)")
            isRunning = false
            continuation.finish()
            return stream
        }

        socketFD = fd

        DispatchQueue.global(qos: .utility).async {
            Self.receiveLoop(fd: fd, continuation: continuation)
        }

        return stream
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        let fd = socketFD
        socketFD = -1

        if fd >= 0 {
            // Drop multicast membership before closing
            var mreq = ip_mreq()
            inet_pton(AF_INET, Self.multicastAddress, &mreq.imr_multiaddr)
            mreq.imr_interface.s_addr = INADDR_ANY.bigEndian
            setsockopt(fd, IPPROTO_IP, IP_DROP_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size))

            close(fd)
        }
    }

    // MARK: - Socket Setup

    private static func createMulticastSocket() throws -> Int32 {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else {
            throw SSDPError.socketCreationFailed(errno: errno, detail: String(cString: strerror(errno)))
        }

        var success = false
        defer { if !success { close(fd) } }

        // Enable address/port reuse so other processes can also bind to 1900
        var reuseAddr: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw SSDPError.socketOptionFailed(option: "SO_REUSEADDR", errno: errno, detail: String(cString: strerror(errno)))
        }

        var reusePort: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &reusePort, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw SSDPError.socketOptionFailed(option: "SO_REUSEPORT", errno: errno, detail: String(cString: strerror(errno)))
        }

        // Bind to INADDR_ANY:1900 to receive multicast NOTIFY messages
        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = multicastPort.bigEndian
        bindAddr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &bindAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw SSDPError.bindFailed(errno: errno, detail: String(cString: strerror(errno)))
        }

        // Join multicast group 239.255.255.250
        var mreq = ip_mreq()
        inet_pton(AF_INET, multicastAddress, &mreq.imr_multiaddr)
        mreq.imr_interface.s_addr = INADDR_ANY.bigEndian

        guard setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size)) == 0 else {
            throw SSDPError.socketOptionFailed(option: "IP_ADD_MEMBERSHIP", errno: errno, detail: String(cString: strerror(errno)))
        }

        success = true
        return fd
    }

    // MARK: - Receive Loop

    private static func receiveLoop(fd: Int32, continuation: AsyncStream<SSDPResponse>.Continuation) {
        var recvBuffer = [UInt8](repeating: 0, count: 4096)

        while true {
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let pollResult = poll(&pfd, 1, pollIntervalMs)

            // Socket was closed (stop() called); poll returns error or POLLNVAL
            if pollResult < 0 || (pfd.revents & Int16(POLLNVAL)) != 0 {
                break
            }

            guard pollResult > 0 && (pfd.revents & Int16(POLLIN)) != 0 else {
                continue
            }

            var fromAddr = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let bytesRead = withUnsafeMutablePointer(to: &fromAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(fd, &recvBuffer, recvBuffer.count, 0, sockaddrPtr, &fromLen)
                }
            }

            guard bytesRead > 0 else { continue }

            let data = Data(recvBuffer[..<bytesRead])
            guard let message = String(data: data, encoding: .utf8) else { continue }

            // Only process NOTIFY ssdp:alive messages for HEOS devices
            guard isHeosNotifyAlive(message) else { continue }

            if let response = SSDPResponse.parse(message) {
                continuation.yield(response)
            }
        }

        continuation.finish()
    }

    private static func isHeosNotifyAlive(_ message: String) -> Bool {
        let lines = message.components(separatedBy: "\r\n")

        guard lines.first?.hasPrefix("NOTIFY") == true else { return false }

        var hasMatchingNT = false
        var isAlive = false

        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("nt:") {
                let value = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                hasMatchingNT = value == heosNotificationType
            } else if lower.hasPrefix("nts:") {
                let value = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                isAlive = value == "ssdp:alive"
            }
        }

        return hasMatchingNT && isAlive
    }
}
