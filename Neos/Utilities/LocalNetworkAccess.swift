import Network
import Observation
import dnssd

/// Whether the system refuses the app the local network. Only a Bonjour browse says so: it waits on a policy error.
@MainActor
@Observable
final class LocalNetworkAccess {
    /// Starts a browse that reports its states, and returns what stops it.
    typealias Probe = @MainActor (_ report: @escaping @Sendable (NWBrowser.State) -> Void) -> () -> Void

    private(set) var isDenied = false
    @ObservationIgnored var onAllowedAgain: () -> Void = {}
    @ObservationIgnored private let probe: Probe
    @ObservationIgnored private var stopProbe: (() -> Void)?

    init(probe: @escaping Probe = LocalNetworkAccess.browseForSpeakers) {
        self.probe = probe
    }

    func check() {
        stopProbe?()
        stopProbe = probe { [weak self] state in
            Task { @MainActor in self?.apply(state) }
        }
    }

    func apply(_ state: NWBrowser.State) {
        guard let denied = Self.isDenial(state), denied != isDenied else { return }
        isDenied = denied
        if !denied { onAllowedAgain() }
    }

    /// Nil while the browse has said nothing either way.
    static func isDenial(_ state: NWBrowser.State) -> Bool? {
        switch state {
        case .ready:
            false
        case .waiting(let error), .failed(let error):
            if case .dns(let code) = error, code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) { true } else { nil }
        default:
            nil
        }
    }

    private static func browseForSpeakers(report: @escaping @Sendable (NWBrowser.State) -> Void) -> () -> Void {
        let browser = NWBrowser(for: .bonjour(type: "_heos-audio._tcp", domain: nil), using: .tcp)
        browser.stateUpdateHandler = report
        browser.start(queue: .main)
        return { browser.cancel() }
    }
}
