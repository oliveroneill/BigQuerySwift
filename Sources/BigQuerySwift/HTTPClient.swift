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
        let request = RestRequest(method: .post, url: url)
        request.messageBody = payload
        request.headerParameters = headers
        request.contentType = "application/json"
        request.response() { body, response, error in
            // We don't want bad responses coming through as errors since the
            // body could still be valid
            if let _ = error as? RestError {
                completionHandler(body, response, nil)
            } else {
                completionHandler(body, response, error)
            }
        }
    }
}
