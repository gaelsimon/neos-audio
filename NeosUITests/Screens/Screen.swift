import XCTest

/// Page Object Model base protocol.
/// Each screen struct wraps element queries for a specific view area.
protocol Screen {
    var app: XCUIApplication { get }
}
