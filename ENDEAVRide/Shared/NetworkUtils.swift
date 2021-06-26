//
//  NetworkUtils.swift
//  ENDEAVRide
//
//  Created by eavride on 6/6/21.
//

import Foundation

class NetworkUtils {
    static func getFromServer(url: URL, header: String?, queryItem: [URLQueryItem]?, handler: @escaping(_ data: Data) -> Void, errorHandler: @escaping(_ error: String) -> Void) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if var com = components {
            if let query = queryItem{
                com.queryItems = query
            }
            var request = URLRequest(url: com.url!)
            if let id = header {
                request.addValue(id, forHTTPHeaderField: "targetid")
            }
            request.addValue(Utils.userId, forHTTPHeaderField: "uid")
            let task = session.dataTask(with: request) {(data, response, error) in
                if let httpResponse = response as? HTTPURLResponse {
                    print("http response status code: \(httpResponse.statusCode)")
                    print("[Network]: \(httpResponse.url?.absoluteString ?? "url unavailable")")
                    guard (200...299).contains(httpResponse.statusCode) else {
                        print ("server error - get")
                        errorHandler(String(describing: httpResponse.statusCode))
                        return
                    }
                }
                if let d = data {
                    handler(d)
                } else {
                    print("get request failed")
                    if let e = error {
                        print("server connection failed")
                        errorHandler(e.localizedDescription)
                    }
                }
            }
            task.resume()
        }
    }
    
    static func postToServer(url: URL, path: String?, parameterDirctionary: [String: Any]?, handler: @escaping(_ data: Data) -> Void, errorHandler: @escaping(_ error: String) -> Void) {
        var request: URLRequest
        if let p = path {
            let u = url.appendingPathComponent(p)
            request = URLRequest(url: u)
        } else {
            request = URLRequest(url: url)
        }
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Utils.userId, forHTTPHeaderField: "uid")
        if let param = parameterDirctionary {
            guard let httpBody = try? JSONSerialization.data(withJSONObject: param, options: []) else {
                return
            }
            request.httpBody = httpBody
        }
        
        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                print("http response status code: \(httpResponse.statusCode)")
                print("[Network]: \(httpResponse.url?.absoluteString ?? "url unavailable")")
                guard (200...299).contains(httpResponse.statusCode) else {
                    print ("server error - post")
                    errorHandler(String(describing: httpResponse.statusCode))
                    return
                }
            }
            if let data = data {
                handler(data)
            } else {
                if let e = error {
                    errorHandler(e.localizedDescription)
                }
            }
            }.resume()
    }
}
