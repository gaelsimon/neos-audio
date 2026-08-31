import Testing
import Network
@testable import HEOSKit

@Suite("TCPTransport Connection State Tests")
struct TCPTransportStateTests {

    @Test func waitingCountsAsADisconnection() {
        #expect(TCPTransport.isDisconnection(.waiting(NWError.posix(.ENETDOWN))))
    }

    @Test func failedCountsAsADisconnection() {
        #expect(TCPTransport.isDisconnection(.failed(NWError.posix(.ECONNRESET))))
    }

    @Test func readyIsNotADisconnection() {
        #expect(TCPTransport.isDisconnection(.ready) == false)
    }

    @Test func preparingIsNotADisconnection() {
        #expect(TCPTransport.isDisconnection(.preparing) == false)
    }

    /// A cancel is our own `disconnect()`; treating it as a drop would kick off a reconnection.
    @Test func cancelledIsNotADisconnection() {
        #expect(TCPTransport.isDisconnection(.cancelled) == false)
    }
}
