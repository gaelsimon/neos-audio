import Network
import Testing
import dnssd
@testable import Neos

@MainActor
struct LocalNetworkAccessTests {
    private static let refusal = NWError.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))

    @Test func aBrowseHeldBackByThePolicyIsARefusal() {
        #expect(LocalNetworkAccess.isDenial(.waiting(Self.refusal)) == true)
        #expect(LocalNetworkAccess.isDenial(.failed(Self.refusal)) == true)
    }

    @Test func aBrowseThatRunsIsAllowed() {
        #expect(LocalNetworkAccess.isDenial(.ready) == false)
    }

    @Test func anyOtherStateSaysNothing() {
        #expect(LocalNetworkAccess.isDenial(.setup) == nil)
        #expect(LocalNetworkAccess.isDenial(.cancelled) == nil)
        #expect(LocalNetworkAccess.isDenial(.waiting(.posix(.ENETDOWN))) == nil)
        #expect(LocalNetworkAccess.isDenial(.failed(.dns(DNSServiceErrorType(kDNSServiceErr_NoSuchRecord)))) == nil)
    }

    @Test func aRefusalStandsUntilABrowseRuns() {
        let access = LocalNetworkAccess(probe: { _ in {} })

        access.apply(.waiting(Self.refusal))
        access.apply(.cancelled)
        #expect(access.isDenied)

        access.apply(.ready)
        #expect(!access.isDenied)
    }

    @Test func thePermissionComingBackIsReportedOnce() {
        let access = LocalNetworkAccess(probe: { _ in {} })
        var reports = 0
        access.onAllowedAgain = { reports += 1 }

        access.apply(.ready)
        access.apply(.waiting(Self.refusal))
        access.apply(.ready)
        access.apply(.ready)

        #expect(reports == 1)
    }

    @Test func checkingAgainStopsTheEarlierBrowse() {
        var started = 0
        var stopped = 0
        let access = LocalNetworkAccess(probe: { _ in
            started += 1
            return { stopped += 1 }
        })

        access.check()
        access.check()

        #expect(started == 2)
        #expect(stopped == 1)
    }

    @Test func whatTheBrowseReportsReachesTheModel() async {
        var report: (@Sendable (NWBrowser.State) -> Void)?
        let access = LocalNetworkAccess(probe: {
            report = $0
            return {}
        })
        access.check()

        report?(.waiting(Self.refusal))
        for _ in 0..<100 where !access.isDenied {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(access.isDenied)
    }

    @Test func theSettingsAdviceNamesThePermissionAndHasAPageToOpen() {
        #expect(LocalNetworkSettings.advice.contains("Local Network"))
        #expect(LocalNetworkSettings.url != nil)
    }
}
