import Testing
import Foundation
@testable import HEOSKit

@Suite("HEOSService Volume Throttle Tests")
struct HEOSServiceThrottleTests {

    @Test @MainActor func volumeThrottlesAreCreatedPerPlayer() async {
        let service = HEOSService(stateUpdater: MockStateUpdater())

        let first = await service.volumeThrottle(for: 1)
        let second = await service.volumeThrottle(for: 2)
        let firstAgain = await service.volumeThrottle(for: 1)

        #expect(first !== second)
        #expect(first === firstAgain)
    }

    @Test @MainActor func groupVolumeThrottlesAreCreatedPerGroup() async {
        let service = HEOSService(stateUpdater: MockStateUpdater())

        let first = await service.groupVolumeThrottle(for: 10)
        let second = await service.groupVolumeThrottle(for: 20)
        let firstAgain = await service.groupVolumeThrottle(for: 10)

        #expect(first !== second)
        #expect(first === firstAgain)
    }

    @Test @MainActor func resetCancelsAndClearsThrottles() async {
        let service = HEOSService(stateUpdater: MockStateUpdater())
        let before = await service.volumeThrottle(for: 1)

        await service.resetVolumeThrottles()

        let after = await service.volumeThrottle(for: 1)
        #expect(before !== after)
    }
}
