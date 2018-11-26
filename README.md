# BigQuerySwift

[![Build Status](https://travis-ci.org/oliveroneill/BigQuerySwift.svg?branch=master)](https://travis-ci.org/oliveroneill/BigQuerySwift)
[![Platform](https://img.shields.io/badge/Swift-4.2-orange.svg)](https://img.shields.io/badge/Swift-4.2-orange.svg)
[![Swift Package Manager](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)

A [BigQuery](https://cloud.google.com/bigquery/) client for Swift.

## Installation
Add this to your Package.swift:

```swift
.package(url: "https://github.com/oliveroneill/BigQuerySwift.git", .upToNextMajor(from: "0.0.1")),
```

## Usage
To get an authentication from your service account:
```swift
let provider = BigQueryAuthProvider()
try! provider.getAuthenticationToken { response in
    switch response {
    case .token(let token):
        // Your token to be passed into BigQueryClient
        print(token)
    case .error(_):
        fatalError("Something went wrong.")
    }
}
```
You'll need to copy your credentials file at `$GOOGLE_APPLICATION_CREDENTIALS`
to `credentials.json` in the directory that the binary is run in.

To insert:
```swift
let client = BigQueryClient<YourEncodableType>(
    authenticationToken: "<ENTER-AUTHENTICATION-TOKEN>",
    projectID: "<ENTER-PROJECT-ID>",
    datasetID: "<ENTER-DATASET-ID>",
    tableName: "<ENTER-TABLE-NAME>"
)
try client.insert(rows: rows) { response in
    switch response {
    case .error(let error):
        fatalError("Error: " + error.localizedDescription)
    case .bigQueryResponse(let response):
        checkErrors(response.insertErrors)
    }
}
```

To query:
```swift
let query = "SELECT * FROM users"
try db.query(query) {
    switch $0 {
    case .error(let e):
        fatalError("Something went wrong.")
    case .queryResponse(let result):
        guard let result = result.rows else {
            guard let errors = result.errors else {
                fatalError("No errors and no rows.")
            }
            print("BigQuery errors: \(errors)")
            return
        }
        printQueryResult(result)
    }
}
```

## Contributing
Feel free to help out. Currently only
[insertAll](https://cloud.google.com/bigquery/docs/reference/rest/v2/tabledata/insertAll)
is supported.