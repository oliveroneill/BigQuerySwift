# BigQuerySwift

[![Build Status](https://travis-ci.org/oliveroneill/BigQuerySwift.svg?branch=master)](https://travis-ci.org/oliveroneill/BigQuerySwift)
[![Platform](https://img.shields.io/badge/Swift-4.2-orange.svg)](https://img.shields.io/badge/Swift-4.2-orange.svg)
[![Swift Package Manager](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)

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