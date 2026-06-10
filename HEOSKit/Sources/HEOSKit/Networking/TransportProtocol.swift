import Foundation

public protocol TransportProtocol: Sendable {
    func connect(host: String, port: Int) async throws
    func disconnect() async
    func send(_ data: Data) async throws
    func receive() -> AsyncThrowingStream<Data, Error>
    var isConnected: Bool { get async }
}
