import XCTest

extension BigQuerySwiftTests {
    static let __allTests = [
        ("testInsert", testInsert),
        ("testInsertError", testInsertError),
        ("testInsertSetsUpRequestCorrectly", testInsertSetsUpRequestCorrectly),
        ("testQuery", testQuery),
        ("testQueryError", testQueryError),
        ("testQueryWithInvalidJSON", testQueryWithInvalidJSON),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BigQuerySwiftTests.__allTests),
    ]
}
#endif
