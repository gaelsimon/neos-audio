import Foundation
import Testing
@testable import Neos

struct SignInErrorTypeTests {
    private static func error(_ message: String) -> NSError {
        NSError(domain: "heos", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    @Test(arguments: [
        ("User not found", "lock.slash"),
        ("Invalid credentials", "lock.slash"),
        ("The request timed out.", "clock.badge.exclamationmark"),
        ("The network connection was lost.", "wifi.slash"),
        ("Speaker busy", "exclamationmark.triangle"),
    ])
    func theSpeakersMessageSortsTheError(message: String, icon: String) {
        #expect(SignInErrorType(Self.error(message)).icon == icon)
    }

    @Test func anyURLErrorIsANetworkError() {
        #expect(SignInErrorType(URLError(.cannotFindHost)).icon == "wifi.slash")
    }

    @Test func anUnknownErrorKeepsTheSpeakersWords() {
        #expect(SignInErrorType(Self.error("Speaker busy")).message == "Speaker busy")
    }

    @Test func eachKnownErrorHasItsOwnExplanation() {
        let messages = [SignInErrorType.authFailed, .networkError, .timeout].map(\.message)
        #expect(Set(messages).count == messages.count)
    }
}
