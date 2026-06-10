import Foundation

public actor SystemService {
    private let connection: HEOSConnection

    public init(connection: HEOSConnection) {
        self.connection = connection
    }

    public func registerForChangeEvents(enable: Bool) async throws {
        try await connection.send(.registerForChangeEvents(enable: enable ? .on : .off))
    }

    public func checkAccount() async throws -> String? {
        let response = try await connection.send(.checkAccount)
        let signedIn = response.message["signed_in"]
        if signedIn != nil {
            return response.message["un"]
        }
        return nil
    }

    public func signIn(username: String, password: String) async throws {
        try await connection.send(.signIn(username: username, password: password))
    }

    public func signOut() async throws {
        try await connection.send(.signOut)
    }

    public func heartBeat() async throws {
        try await connection.send(.heartBeat)
    }

    public func reboot() async throws {
        try await connection.sendFireAndForget(.reboot)
    }
}
