import Foundation

/// Encodable row for BigQuery payload
private struct Row<T: Encodable>: Encodable {
    let json: T
}

/// Request payload for insert
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

/// Request payload for query
private struct QueryPayload: Encodable {
    let kind: String
    let query: String
    let useLegacySql = false

    init(query: String) {
        self.kind = "bigquery#queryRequest"
        self.query = query
    }
}

/// An error in the response from BigQuery
public struct BigQueryError: Decodable, Equatable {
    public let reason: String
    public let location: String
    public let debugInfo: String
    public let message: String
}

/// Insert error from response
public struct InsertError: Decodable, Equatable {
    public let index: Int
    public let errors: [BigQueryError]
}

/// BigQuery response
public struct InsertHTTPResponse: Decodable, Equatable {
    public let insertErrors: [InsertError]?
}

/// Enum from insert call
///
/// - error: An error with network or decoding JSON
/// - insertResponse: Response from BigQuery
public enum InsertResponse {
    case error(Error)
    case insertResponse(InsertHTTPResponse)
}

/// Schema value definition
public struct SchemaValue: Decodable {
    let name: String
    let type: String
    let mode: String
}

/// BigQuery query response schema
public struct BigQuerySchema: Decodable {
    let fields: [SchemaValue]
}

/// Query response underlying value
public struct Value: Decodable {
    let v: String?
}

public struct ValueList: Decodable {
    let v: [Value]
}

/// A nested value for the query response
///
/// - repeating: A list of values for repeating value in schema
/// - nonRepeating: A single value for non-repeating value
/// - missingValue: An error if it wasn't either repeating or non-repeating
public enum NestedValue: Decodable {
    case repeating([Value]), nonRepeating(String?)

    enum CodingKeys: String, CodingKey {
        case v
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([Value].self, forKey: .v) {
            self = .repeating(list)
            return
        }
        if let value = try? container.decode(String?.self, forKey: .v) {
            self = .nonRepeating(value)
            return
        }
        throw NestedValue.missingValue
    }

    enum NestedValue: Error {
        case missingValue
    }
}

/// Row in query response
public struct BigQueryRow: Decodable {
    let f: [NestedValue]
}

/// BigQuery query response
public struct QueryHTTPResponse: Decodable {
    let totalRows: String?
    let schema: BigQuerySchema?
    let rows: [BigQueryRow]?
    let pageToken: String?
    let totalBytesProcessed: String
    let errors: [BigQueryError]?

    /// Convert query response from schema and rows into a single dictionary
    /// with key being schema name and value being row value
    ///
    /// - Returns: A dictionary of the response or nil if the schema or rows
    /// are nil
    func toDictionary() -> [[String:Any]]? {
        guard let rows = self.rows, let schema = self.schema else {
            return nil
        }
        var rtn = [[String:Any]]()
        for row in rows {
            var rowDict = [String:Any]()
            for i in 0..<row.f.count {
                switch row.f[i] {
                case .repeating(let values):
                    rowDict[schema.fields[i].name] = values.map { $0.v }
                case .nonRepeating(let value):
                    rowDict[schema.fields[i].name] = value
                }
            }
            rtn.append(rowDict)
        }
        return rtn
    }
}

/// A simplified response to be returned via BigQuerySwift's query function
public struct QueryResponse<T: Decodable>: Decodable {
    public let rows: [T]?
    public let pageToken: String?
    public let totalBytesProcessed: String
    public let errors: [BigQueryError]?

    init(rows: [T]?, errors: [BigQueryError]?, pageToken: String?,
         totalBytesProcessed: String) {
        self.rows = rows
        self.pageToken = pageToken
        self.totalBytesProcessed = totalBytesProcessed
        self.errors = errors
    }

    init(dict: [[String:Any]], errors: [BigQueryError]?, pageToken: String?,
         totalBytesProcessed: String) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        self.rows = try decoder.decode(
            [T].self,
            from: jsonData
        )
        self.pageToken = pageToken
        self.totalBytesProcessed = totalBytesProcessed
        self.errors = errors
    }

    init(errors: [BigQueryError]?, pageToken: String?,
         totalBytesProcessed: String) throws {
        self.errors = errors
        self.pageToken = pageToken
        self.totalBytesProcessed = totalBytesProcessed
        self.rows = nil
    }
}

/// Enum from insert call
///
/// - error: An error with network or decoding JSON
/// - queryResponse: Response from BigQuery
public enum QueryCallResponse<T : Decodable> {
    case error(Error)
    case queryResponse(QueryResponse<T>)
}

public struct BigQueryClient<T : Encodable> {
    private let insertUrl: String
    private let queryUrl: String
    private let authenticationToken: String
    private let client: HTTPClient

    init(authenticationToken: String, projectID: String, datasetID: String,
         tableName: String, client: HTTPClient) {
        self.authenticationToken = authenticationToken
        self.client = client
        self.insertUrl = "https://www.googleapis.com/bigquery/v2/projects/" + projectID + "/datasets/" + datasetID + "/tables/" + tableName + "/insertAll"
        self.queryUrl = "https://www.googleapis.com/bigquery/v2/projects/" + projectID + "/queries"
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
            url: insertUrl,
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
                completionHandler(.insertResponse(response))
            } catch {
                completionHandler(.error(error))
            }
        }
    }

    public func query<V:Decodable>(_ query: String, completionHandler: @escaping (QueryCallResponse<V>) -> Void) throws {
        let data = try JSONEncoder().encode(QueryPayload(query: query))
        client.post(
            url: queryUrl,
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
                    QueryHTTPResponse.self,
                    from: body
                )
                let parsed: QueryResponse<V>
                if let simpleDict = response.toDictionary() {
                    parsed = try QueryResponse(
                        dict: simpleDict,
                        errors: response.errors,
                        pageToken: response.pageToken,
                        totalBytesProcessed: response.totalBytesProcessed
                    )
                } else {
                    parsed = try QueryResponse(
                        errors: response.errors,
                        pageToken: response.pageToken,
                        totalBytesProcessed: response.totalBytesProcessed
                    )
                }
                completionHandler(.queryResponse(parsed))
            } catch {
                completionHandler(.error(error))
            }
        }
    }
}
