import Foundation

/// Encodable row for BigQuery payload
private struct Row<T: Encodable>: Encodable {
    let json: T
}

/// Request payload
private struct InsertPayload<T: Encodable>: Encodable {
    let kind: String
    let skipInvalidRows: Bool
    let ignoreUnknownValues: Bool
    let rows: [Row<T>]

    init(rows: [T], skipInvalidRows: Bool = false,
         ignoreUnknownValues: Bool = false) {
        self.kind = "bigquery#tableDataInsertAllRequest"
        self.skipInvalidRows = skipInvalidRows
        self.ignoreUnknownValues = ignoreUnknownValues
        self.rows = rows.map { Row(json: $0) }
    }
}

/// An error in the response from BigQuery
public struct BigQueryError: Decodable, Equatable {
    let reason: String
    let location: String
    let debugInfo: String
    let message: String
}

/// Insert error from response
public struct InsertError: Decodable, Equatable {
    let index: Int
    let errors: [BigQueryError]
}

/// BigQuery response
public struct InsertHTTPResponse: Decodable, Equatable {
    let insertErrors: [InsertError]?
}

/// Enum from insert call
///
/// - error: An error with network or decoding JSON
/// - bigQueryResponse: Response from BigQuery
public enum InsertResponse {
    case error(Error)
    case bigQueryResponse(InsertHTTPResponse)
}

public struct BigQueryClient<T : Encodable> {
    private let url: String
    private let authenticationToken: String
    private let client: HTTPClient

    init(authenticationToken: String, projectID: String, datasetID: String,
         tableName: String, client: HTTPClient) {
        self.authenticationToken = authenticationToken
        self.client = client
        self.url = "https://www.googleapis.com/bigquery/v2/projects/" + projectID + "/datasets/" + datasetID + "/tables/" + tableName + "/insertAll"
    }

    public init(authenticationToken: String, projectID: String,
                datasetID: String, tableName: String) {
        self.init(
            authenticationToken: authenticationToken, projectID: projectID,
            datasetID: datasetID, tableName: tableName,
            client: SwiftyRequestClient()
        )
    }

    public func insert(rows: [T], completionHandler: @escaping (InsertResponse) -> Void) throws {
        let data = try JSONEncoder().encode(InsertPayload(rows: rows))
        client.post(
            url: url,
            payload: data,
            headers: ["Authorization": "Bearer " + authenticationToken]
        ) { (body, response, error) in
            if let error = error {
                completionHandler(.error(error))
                return
            }
            guard let body = body else {
                fatalError("Response is empty")
            }
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(
                    InsertHTTPResponse.self,
                    from: body
                )
                completionHandler(.bigQueryResponse(response))
            } catch {
                completionHandler(.error(error))
            }
        }
    }
}
