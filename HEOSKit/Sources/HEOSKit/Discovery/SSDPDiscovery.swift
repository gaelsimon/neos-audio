import Foundation

#if canImport(Darwin)
import Darwin
#endif

public struct SSDPDiscovery: Sendable {
    private static let multicastAddress = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900
    private static let searchTarget = "urn:schemas-denon-com:device:ACT-Denon:1"

    static let mSearchMessage: String = "M-SEARCH * HTTP/1.1\r\n"
        + "HOST: 239.255.255.250:1900\r\n"
        + "MAN: \"ssdp:discover\"\r\n"
        + "MX: 3\r\n"
        + "ST: urn:schemas-denon-com:device:ACT-Denon:1\r\n"
        + "\r\n"

    public init() {}

    public func search(timeout: TimeInterval = 5.0) async throws -> [SSDPResponse] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let responses = try Self.performSearch(timeout: timeout)
                    continuation.resume(returning: responses)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static let sendCount = 3
    private static let sendIntervalMs: Int32 = 300
    private static let pollIntervalMs: Int32 = 50
    private static let gracePeriod: TimeInterval = 0.5

    /// Creates a UDP multicast socket with address/port reuse and TTL configured,
    /// bound to an ephemeral port on INADDR_ANY.
    private static func createMulticastSocket() throws -> Int32 {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else {
            throw SSDPError.socketCreationFailed(errno: errno, detail: String(cString: strerror(errno)))
        }

        // Enable address/port reuse
        var reuseAddr: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            close(fd)
            throw SSDPError.socketOptionFailed(option: "SO_REUSEADDR", errno: errno, detail: String(cString: strerror(errno)))
        }

        var reusePort: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &reusePort, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            close(fd)
            throw SSDPError.socketOptionFailed(option: "SO_REUSEPORT", errno: errno, detail: String(cString: strerror(errno)))
        }

        // Set multicast TTL to 2 for LAN
        var ttl: UInt8 = 2
        guard setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size)) == 0 else {
            close(fd)
            throw SSDPError.socketOptionFailed(option: "IP_MULTICAST_TTL", errno: errno, detail: String(cString: strerror(errno)))
        }

        // Bind to INADDR_ANY:0 (ephemeral port for unicast M-SEARCH responses)
        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = 0
        bindAddr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &bindAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw SSDPError.bindFailed(errno: errno, detail: String(cString: strerror(errno)))
        }

        return fd
    }

    private static func performSearch(timeout: TimeInterval) throws -> [SSDPResponse] {
        let fd = try createMulticastSocket()
        defer { close(fd) }

        var destAddr = prepareMulticastAddress()

        guard let messageData = mSearchMessage.data(using: .utf8) else {
            throw SSDPError.socketCreationFailed(errno: 0, detail: "Failed to encode M-SEARCH message")
        }

        var responses: [SSDPResponse] = []
        var recvBuffer = [UInt8](repeating: 0, count: 4096)
        let startTime = Date()
        var firstResponseTime: Date?
        var sendsSent = 0
        var nextSendTime: TimeInterval = 0

        while true {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= timeout { break }
            if let firstTime = firstResponseTime,
               Date().timeIntervalSince(firstTime) >= gracePeriod { break }

            // Send M-SEARCH at scheduled intervals (t=0, t=300ms, t=600ms)
            if sendsSent < sendCount && elapsed >= nextSendTime {
                try sendMSearch(fd: fd, data: messageData, dest: &destAddr, isFirst: sendsSent == 0)
                sendsSent += 1
                nextSendTime = elapsed + Double(sendIntervalMs) / 1000.0
            }

            // Poll for readable data with short timeout
            if let response = pollForResponse(fd: fd, buffer: &recvBuffer) {
                if !responses.contains(where: { $0.location == response.location }) {
                    responses.append(response)
                    if firstResponseTime == nil { firstResponseTime = Date() }
                }
            }
        }

        return responses
    }

    private static func prepareMulticastAddress() -> sockaddr_in {
        var destAddr = sockaddr_in()
        destAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = multicastPort.bigEndian
        inet_pton(AF_INET, multicastAddress, &destAddr.sin_addr)
        return destAddr
    }

    private static func sendMSearch(fd: Int32, data: Data, dest: inout sockaddr_in, isFirst: Bool) throws {
        let sent = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &dest) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(fd, buffer.baseAddress, buffer.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        if sent < 0 && isFirst {
            throw SSDPError.sendFailed(errno: errno, detail: String(cString: strerror(errno)))
        }
    }

    private static func pollForResponse(fd: Int32, buffer: inout [UInt8]) -> SSDPResponse? {
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let pollResult = poll(&pfd, 1, pollIntervalMs)
        guard pollResult > 0 && (pfd.revents & Int16(POLLIN)) != 0 else { return nil }

        var fromAddr = sockaddr_in()
        var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bytesRead = withUnsafeMutablePointer(to: &fromAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                recvfrom(fd, &buffer, buffer.count, 0, sockaddrPtr, &fromLen)
            }
        }

        guard bytesRead > 0 else { return nil }
        let data = Data(buffer[..<bytesRead])
        guard let responseString = String(data: data, encoding: .utf8) else { return nil }
        return SSDPResponse.parse(responseString)
    }
}

public struct SSDPResponse: Equatable, Sendable {
    public let location: String
    public let server: String
    public let st: String
    public let usn: String
    public let host: String

    public init(location: String, server: String = "", st: String = "", usn: String = "", host: String = "") {
        self.location = location
        self.server = server
        self.st = st
        self.usn = usn
        self.host = host
    }

    public static func parse(_ response: String) -> Self? {
        var headers: [String: String] = [:]
        let lines = response.components(separatedBy: "\r\n")

        for line in lines {
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        guard let location = headers["location"] else { return nil }

        // Extract host from location URL
        var host = ""
        if let url = URL(string: location), let urlHost = url.host {
            host = urlHost
        }

        return Self(
            location: location,
            server: headers["server"] ?? "",
            st: headers["st"] ?? "",
            usn: headers["usn"] ?? "",
            host: host
        )
    }
}

public enum SSDPError: Error, Sendable, CustomStringConvertible, LocalizedError {
    case socketCreationFailed(errno: Int32, detail: String)
    case socketOptionFailed(option: String, errno: Int32, detail: String)
    case bindFailed(errno: Int32, detail: String)
    case sendFailed(errno: Int32, detail: String)
    case timeout

    public var description: String {
        switch self {
        case .socketCreationFailed(let code, let detail):
            return "SSDP socket creation failed (errno \(code): \(detail))"
        case .socketOptionFailed(let option, let code, let detail):
            return "SSDP setsockopt \(option) failed (errno \(code): \(detail))"
        case .bindFailed(let code, let detail):
            return "SSDP bind failed (errno \(code): \(detail))"
        case .sendFailed(let code, let detail):
            return "SSDP sendto failed (errno \(code): \(detail))"
        case .timeout:
            return "SSDP discovery timed out"
        }
    }

    public var errorDescription: String? {
        description
    }
}
