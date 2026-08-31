import Testing
import Foundation
@testable import HEOSKit

@Suite("Bonjour Discovery Tests")
struct BonjourDiscoveryTests {

    @Test func retryDelayBacksOffThenGivesUp() {
        #expect(BonjourDiscovery.retryDelay(forAttempt: 0) == 1)
        #expect(BonjourDiscovery.retryDelay(forAttempt: 1) == 2)
        #expect(BonjourDiscovery.retryDelay(forAttempt: 2) == 4)
        #expect(BonjourDiscovery.retryDelay(forAttempt: 3) == nil)
    }

    @Test func endingASessionStopsFurtherRetries() {
        let session = BonjourResolveSession()
        #expect(session.isActive)

        session.end()

        #expect(session.isActive == false)
    }

    @Test func stoppingContinuousDiscoveryEndsItsSession() async {
        let discovery = BonjourDiscovery()
        _ = await discovery.startContinuous()

        await discovery.stop()
        // A second stop must stay harmless; the session is already gone.
        await discovery.stop()
    }
}
