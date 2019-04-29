import XCTest
@testable import BigQuerySwift

/// Implement Equatable for testing purposes
extension QueryResponse: Equatable where T: Equatable {
    public static func == (lhs: QueryResponse<T>, rhs: QueryResponse<T>) -> Bool {
        return lhs.rows == rhs.rows && lhs.pageToken == rhs.pageToken &&
            lhs.totalBytesProcessed == rhs.totalBytesProcessed &&
            lhs.errors == rhs.errors
    }
}

final class BigQuerySwiftTests: XCTestCase {
    private struct TestRow: Codable, Equatable {
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
            guard case let .success(r) = response else {
                XCTFail("Unexpected error")
                return
            }
            XCTAssertEqual(expected, r)
        }
    }

    func testInsertSetsUpRequestCorrectly() {
        let httpClient = MockClient(response: (nil, nil, TestError.test))
        let expectedUrl = "https://www.googleapis.com/bigquery/v2/projects/id-1234/datasets/dataset_name/tables/table_name/insertAll"
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
            // TODO: figure out how to test payload since JSON encoding does
            // not deterministically set order
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
            guard case let .failure(e) = response else {
                XCTFail("Unexpected error")
                return
            }
            XCTAssertEqual(expected, e as! BigQuerySwiftTests.TestError)
        }
    }

    /// BigQuery returns all values as strings. You can decode to specific types
    /// as needed but for these tests we just use strings for simplicity
    private struct RowOfStrings: Codable, Equatable {
        let testName: String
        let testVal: String
        let testArray: [String]
    }

    func testQuery() {
        let query = "SELECT * FROM table_name WHERE bla"
        let data = """
        {
         "kind": "bigquery#queryResponse",
         "schema": {
          "fields": [
           {
            "name": "testName",
            "type": "STRING",
            "mode": "REQUIRED"
           },
           {
            "name": "testVal",
            "type": "STRING",
            "mode": "NULLABLE"
           },
           {
            "name": "testArray",
            "type": "STRING",
            "mode": "REPEATED"
           }
          ]
         },
         "jobReference": {
          "projectId": "projectId123",
          "jobId": "dsjfsdkjfs",
         },
         "totalRows": "12",
         "rows": [
          {
            "f": [
              {
                "v": "a name"
              },
              {
                "v": "val"
              },
              {
                "v": [
                  {
                    "v": "test"
                  }
                ]
              }
            ]
          },
          {
            "f": [
              {
                "v": "another name..."
              },
              {
                "v": "x"
              },
              {
                "v": [
                  {
                    "v": "xyz"
                  },
                  {
                    "v": "x"
                  }
                ]
              }
            ]
          },
          {
            "f": [
              {
                "v": "name1"
              },
              {
                "v": "y"
              },
              {
                "v": []
              }
            ]
          }
         ],
         "totalBytesProcessed": "120",
          "errors": [
            {
              "reason": "bla",
              "location": "line 1",
              "debugInfo": "test",
              "message": "a message"
            }
          ]
        }
        """.data(using: .utf8)
        let rows = [
            RowOfStrings(testName: "a name", testVal: "val", testArray: ["test"]),
            RowOfStrings(testName: "another name...", testVal: "x", testArray: ["xyz", "x"]),
            RowOfStrings(testName: "name1", testVal: "y", testArray: [])
        ]
        let errors = [
            BigQueryError(
                reason: "bla",
                location: "line 1",
                debugInfo: "test",
                message: "a message"
            )
        ]
        let expected = QueryResponse(
            rows: rows,
            errors: errors,
            pageToken: nil,
            totalBytesProcessed: "120"
        )
        let client = BigQueryClient<TestRow>(
            authenticationToken: authenticationToken,
            projectID: projectID,
            datasetID: datasetID,
            tableName: tableName,
            client: MockClient(response: (data, nil, nil))
        )
        try! client.query(query) { (response: QueryCallResponse<RowOfStrings>) in
            guard case let .queryResponse(r) = response else {
                XCTFail("Unexpected error \(response)")
                return
            }
            XCTAssertEqual(expected, r)
        }
    }

    func testQueryWithInvalidJSON() {
        let query = "SELECT * FROM table_name WHERE bla"
        let data = """
        {
          "kind": "bigquery#tableDataInsertAllResponse",
          "some_other_thing": []
        }
        """.data(using: .utf8)
        let client = BigQueryClient<TestRow>(
            authenticationToken: authenticationToken,
            projectID: projectID,
            datasetID: datasetID,
            tableName: tableName,
            client: MockClient(response: (data, nil, nil))
        )
        try! client.query(query) { (response: QueryCallResponse<TestRow>) in
            guard case let .error(e) = response else {
                XCTFail("Unexpected success")
                return
            }
            guard case .keyNotFound(_)? = e as? DecodingError else {
                XCTFail("Unexpected error \(e)")
                return
            }
        }
    }

    func testQueryError() {
        let expected = TestError.test
        let client = BigQueryClient<TestRow>(
            authenticationToken: authenticationToken,
            projectID: projectID,
            datasetID: datasetID,
            tableName: tableName,
            client: MockClient(response: (nil, nil, expected))
        )
        try! client.query("") { (response: QueryCallResponse<RowOfStrings>) in
            guard case let .error(e) = response else {
                XCTFail("Unexpected error")
                return
            }
            XCTAssertEqual(expected, e as! BigQuerySwiftTests.TestError)
        }
    }
}
