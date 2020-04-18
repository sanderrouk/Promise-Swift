import XCTest
@testable import Promise

final class PromiseTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Promise().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
