# BigQuerySwift

A [BigQuery](https://cloud.google.com/bigquery/) client for Swift.

## Usage
```swift
let client = BigQueryClient<YourEncodableType>(
    authenticationToken: "<ENTER-AUTHENTICATION-TOKEN>",
    projectID: "<ENTER-PROJECT-ID>",
    datasetID: "<ENTER-DATASET-ID>",
    tableName: "<ENTER-TABLE-NAME>"
)
try! client.insert(rows: rows) { response in
    switch response {
    case .error(let error):
        fatalError("Error: " + error.localizedDescription)
    case .bigQueryResponse(let response):
        checkErrors(response.insertErrors)
    }
}
```

## Contributing
Feel free to help out. Currently only
[insertAll](https://cloud.google.com/bigquery/docs/reference/rest/v2/tabledata/insertAll)
is supported.