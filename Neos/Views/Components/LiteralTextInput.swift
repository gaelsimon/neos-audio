import SwiftUI

/// Text typed as is: no capital, no correction, and on a touch keyboard the keys that suit it.
enum LiteralTextInput {
    case ipAddress
    case email
    case url
}

extension View {
    func literalTextInput(_ kind: LiteralTextInput) -> some View {
        #if os(iOS)
        keyboardType(kind.keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }
}

#if os(iOS)
private extension LiteralTextInput {
    var keyboard: UIKeyboardType {
        switch self {
        // The decimal pad's separator follows the region, and an address needs the full stop.
        case .ipAddress: .numbersAndPunctuation
        case .email: .emailAddress
        case .url: .URL
        }
    }
}
#endif
