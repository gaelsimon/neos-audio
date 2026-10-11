import Foundation
import NeosDomain
import Security
import os

private let keychainLogger = Logger(subsystem: "com.galela.neos", category: "keychain")

enum SignInErrorType {
    case authFailed
    case networkError
    case timeout
    case unknown(String)

    var message: String {
        switch self {
        case .authFailed:
            return "Invalid email or password. Please check your credentials."
        case .networkError:
            return "Unable to reach the server. Check your network connection."
        case .timeout:
            return "Connection timed out. Please try again."
        case .unknown(let msg):
            return msg
        }
    }

    var icon: String {
        switch self {
        case .authFailed: return "lock.slash"
        case .networkError: return "wifi.slash"
        case .timeout: return "clock.badge.exclamationmark"
        case .unknown: return "exclamationmark.triangle"
        }
    }
}

@Observable
@MainActor
final class AccountViewModel {
    private let service: any AudioService
    private let state: AppState

    var onAccountChanged: (() -> Void)?

    var username: String = ""
    var password: String = ""
    var isSigningIn: Bool = false
    var isSigningOut: Bool = false
    var signInError: SignInErrorType?
    var rememberMe: Bool {
        didSet {
            UserDefaults.standard.set(rememberMe, forKey: "settings.rememberMe")
            if !rememberMe {
                deleteCredentials()
            }
        }
    }
    private let signInTask = CancellableTaskHandle()
    private let signOutTask = CancellableTaskHandle()
    private let accountCheckTask = CancellableTaskHandle()
    private let operationTracker = RequestTracker()
    /// A failed sign-in also signs the speaker out; never retry it with the credentials that just failed.
    private var failedCredentials: String?

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
        self.rememberMe = UserDefaults.standard.object(forKey: "settings.rememberMe") as? Bool ?? true
        loadCredentials()
    }

    func signIn() {
        guard !username.isEmpty, !password.isEmpty else { return }
        signOutTask.cancel()
        let requestID = operationTracker.next()
        isSigningIn = true
        signInError = nil
        signInTask.replace(with: Task {
            do {
                try await service.signIn(username: username, password: password)
                guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
                onAccountChanged?()
                failedCredentials = nil
                state.signedInUser = username
                if rememberMe { saveCredentials() }
                isSigningIn = false
                await refreshSources(untilAvailable: true)
                return
            } catch {
                guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
                signInError = Self.categorizeError(error)
                failedCredentials = "\(username)\n\(password)"
            }
            guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isSigningIn = false
            // The speaker drops its session on a failed sign-in: show what it now reports.
            state.setSignedInUser(try? await service.checkAccount())
            await refreshSources(untilAvailable: false)
        })
    }

    func signOut() {
        signInTask.cancel()
        let requestID = operationTracker.next()
        isSigningOut = true
        signOutTask.replace(with: Task {
            do {
                try await service.signOut()
                guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
                onAccountChanged?()
                state.signedInUser = nil
                deleteCredentials()
                await refreshSources(untilAvailable: false)
            } catch {
                guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
                state.error = .accountFailed(error.localizedDescription)
            }
            guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isSigningOut = false
        })
    }

    /// The speaker reports no account but the user asked to be remembered: sign in again, once per report.
    func restoreSession() {
        guard rememberMe, !username.isEmpty, !password.isEmpty, state.signedInUser == nil, !isSigningIn,
              failedCredentials != "\(username)\n\(password)" else { return }
        signIn()
    }

    // The speaker sends no sources_changed for an account change, and marks services available a moment after a sign-in.
    private func refreshSources(untilAvailable: Bool) async {
        for attempt in 1...5 {
            guard let sources = try? await service.getMusicSources(), !Task.isCancelled else { return }
            state.setMusicSources(sources)
            if !untilAvailable || sources.contains(where: { $0.type == "music_service" && $0.available }) || attempt == 5 { return }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func checkAccount() {
        let requestID = operationTracker.next()
        accountCheckTask.replace(with: Task {
            do {
                if let user = try await service.checkAccount() {
                    guard operationTracker.isCurrent(requestID), !Task.isCancelled else { return }
                    state.signedInUser = user
                }
            } catch {
                keychainLogger.debug("Account check failed (not signed in or network error): \(error.localizedDescription)")
            }
        })
    }

    // MARK: - Keychain

    private static let keychainService = "com.galela.neos.heos-account"
    private static let legacyKeychainService = "com.neos.heos-account"

    private func saveCredentials() {
        guard !DemoSession.isActive else { return }
        let payload = ["u": username, "p": password]
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            keychainLogger.warning("Keychain save failed: \(status)")
        }
    }

    private func loadCredentials() {
        guard rememberMe else { return }
        migrateLegacyKeychainIfNeeded()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data {
            // Try JSON format first (current)
            if let dict = try? JSONDecoder().decode([String: String].self, from: data),
               let u = dict["u"], let p = dict["p"] {
                username = u
                password = p
            } else if let str = String(data: data, encoding: .utf8) {
                // Legacy colon format; migrates to JSON on next save
                let parts = str.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    username = String(parts[0])
                    password = String(parts[1])
                }
            }
        } else if status != errSecItemNotFound {
            keychainLogger.warning("Keychain load failed: \(status)")
        }
    }

    private func deleteCredentials() {
        guard !DemoSession.isActive else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecUseDataProtectionKeychain as String: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            keychainLogger.warning("Keychain delete failed: \(status)")
        }
        username = ""
        password = ""
    }

    /// Move any existing keychain item from the legacy service name to the current one.
    /// Runs once per launch; no-op when the legacy entry is absent.
    private func migrateLegacyKeychainIfNeeded() {
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.legacyKeychainService,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(legacyQuery as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return }

        let newQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: data
        ]
        SecItemDelete(newQuery as CFDictionary)
        let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            keychainLogger.warning("Keychain migration save failed: \(addStatus); keeping legacy entry")
            return
        }

        let deleteLegacy: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.legacyKeychainService,
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(deleteLegacy as CFDictionary)
    }

    // MARK: - Error Categorization

    private static func categorizeError(_ error: Error) -> SignInErrorType {
        let message = error.localizedDescription.lowercased()
        let authKeywords = ["user not found", "invalid", "credentials", "sign in", "password"]
        if authKeywords.contains(where: { message.contains($0) }) {
            return .authFailed
        }
        if message.contains("timeout") || message.contains("timed out") {
            return .timeout
        }
        let networkKeywords = ["network", "connection", "offline", "not connected"]
        if networkKeywords.contains(where: { message.contains($0) }) || (error as? URLError) != nil {
            return .networkError
        }
        return .unknown(error.localizedDescription)
    }
}
