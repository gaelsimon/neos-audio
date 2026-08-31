import Foundation
import ServiceManagement

/// Login-item registration, abstracted so tests never touch the real system service.
protocol LoginItemService {
    var isEnabled: Bool { get }
    var requiresApproval: Bool { get }
    func register() throws
    func unregister() throws
}

struct SystemLoginItemService: LoginItemService {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
