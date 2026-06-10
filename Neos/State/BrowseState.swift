import Foundation
import NeosDomain

@Observable
@MainActor
final class BrowseState {
    var musicSources: [MusicSource] = []
    var serviceCapabilities: [Int: ServiceCapabilities] = [:]
    var searchCriteria: [Int: [SearchCriteria]] = [:]
}
