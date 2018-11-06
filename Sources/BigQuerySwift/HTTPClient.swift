import Foundation

import SwiftyRequest

/// A protocol for making HTTP requests
public protocol HTTPClient {
    func post(url: String, payload: Data,
              headers: [String:String],
              completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void)
}

/// An implementation of HTTPClient using SwiftyRequest
public class SwiftyRequestClient: HTTPClient {
    public func post(url: String, payload: Data,
              headers: [String:String],
              completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        let request = RestRequest(method: .get, url: url)
        request.messageBody = payload
        request.headerParameters = headers
        request.contentType = "application/json"
        request.response(completionHandler: completionHandler)
    }
}
