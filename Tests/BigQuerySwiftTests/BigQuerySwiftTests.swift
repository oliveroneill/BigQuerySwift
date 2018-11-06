import XCTest
@testable import BigQuerySwift

final class BigQuerySwiftTests: XCTestCase {
    private struct TestRow: Encodable {
        let testName: String
        let testVal: String
        let testArray: [String]
        let testInt: Int
    }

    private let authenticationToken = "TEST_TOKEN_123"
    private let projectID = "id-1234"
    private let datasetID = "dataset_name"
    private let tableName = "table_name"
    private let rows = [
        TestRow(testName: "name", testVal: "another", testArray: ["x", "y"], testInt: 1),
        TestRow(testName: "two", testVal: "val", testArray: ["z", "the"], testInt: 53),
    ]

    private class MockClient: HTTPClient {
        private let response: (Data?, HTTPURLResponse?, Error?)
        var calls: [(url: String, payload: Data, headers: [String : String])] = []
        init(response: (Data?, HTTPURLResponse?, Error?)) {
            self.response = response
        }

        func post(url: String, payload: Data, headers: [String : String],
                  completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
            calls.append((url: url, payload: payload, headers: headers))
            completionHandler(response.0, response.1, response.2)
        }
    }

    private enum TestError: Error {
        case test
    }

    func testInsert() {
        let data = """
        {
          "kind": "bigquery#tableDataInsertAllResponse",
          "insertErrors": [
            {
              "index": 1,
              "errors": [
                {
                  "reason": "bla",
                  "location": "line 1",
                  "debugInfo": "test",
                  "message": "a message"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)
        let expected = InsertHTTPResponse(insertErrors: [
            InsertError(index: 1, errors: [
                BigQueryError(
                    reason: "bla",
                    location: "line 1",
                    debugInfo: "test",
                    message: "a message"
                )
                ])
            ])
        let client = BigQueryClient<TestRow>(
            authenticationToken: authenticationToken,
            projectID: projectID,
            datasetID: datasetID,
            tableName: tableName,
            client: MockClient(response: (data, nil, nil))
        )
        try! client.insert(rows: rows) { response in
            guard case let .bigQueryResponse(r) = response else {
                print("Unexpected error")
                return
            }
            XCTAssertEqual(expected, r)
        }
    }

    func testInsertSetsUpRequestCorrectly() {
        let httpClient = MockClient(response: (nil, nil, TestError.test))
        let expectedUrl = "https://www.googleapis.com/bigquery/v2/projects/id-1234/datasets/dataset_name/tables/table_name/insertAll"
        let expectedPayload = """
        {"skipInvalidRows":false,"ignoreUnknownValues":false,"kind":"bigquery#tableDataInsertAllRequest","rows":[{"json":{"testVal":"another","testInt":1,"testArray":["x","y"],"testName":"name"}},{"json":{"testVal":"val","testInt":53,"testArray":["z","the"],"testName":"two"}}]}
        """.data(using: .utf8)!
        let expectedHeaders = ["Authorization": "Bearer " + authenticationToken]
        let client = BigQueryClient<TestRow>(
            authenticationToken: authenticationToken,
            projectID: projectID,
            datasetID: datasetID,
            tableName: tableName,
            client: httpClient
        )
        try! client.insert(rows: rows) { _ in
            XCTAssertEqual(1, httpClient.calls.count)
            XCTAssertEqual(expectedUrl, httpClient.calls[0].url)
            XCTAssertEqual(expectedPayload, httpClient.calls[0].payload)
            XCTAssertEqual(expectedHeaders, httpClient.calls[0].headers)
        }
    }

    func testInsertError() {
        let expected = TestError.test
        let client = BigQueryClient<TestRow>(
            authenticationToken: authenticationToken,
            projectID: projectID,
            datasetID: datasetID,
            tableName: tableName,
            client: MockClient(response: (nil, nil, expected))
        )
        try! client.insert(rows: rows) { response in
            guard case let .error(e) = response else {
                print("Unexpected success")
                return
            }
            XCTAssertEqual(expected, e as! BigQuerySwiftTests.TestError)
        }
    }
}
