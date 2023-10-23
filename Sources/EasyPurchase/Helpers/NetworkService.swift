//
//  NetworkService.swift
//
//
//  Created by Yevhenii Korsun on 23.10.2023.
//

import Foundation

enum NetworkErrors: Error {
    case badUrl
}

enum NetworkService {
    enum TrackerEndpoint: String {
        case configure, trackPurchase, trackAllPurchases
        
        var path: String {
            switch self {
            case .configure: return "app-user"
            case .trackPurchase: return "transaction"
            case .trackAllPurchases: return "transactions"
            }
        }
    }
    
    private static let baseUrl = URL(string: "https://apieasytracker.sandstorm-software.com")
    
    static func send<T: DictionaryConvertable>(_ data: T, endpoint: TrackerEndpoint) {
        guard let url = baseUrl?.appendingPathComponent(endpoint.path) else {
            print("!@ANALITIC ERROR in \(endpoint.rawValue): BadURL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let dictionary = data.toDictionary()
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted)
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let string = String(data: jsonData, encoding: .utf8) {
                print("!@ANALITIC \(endpoint.rawValue) data:\n \(string.utf8)")
            }
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("!@ANALITIC ERROR in \(endpoint.rawValue): \(error.localizedDescription)")
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    print("!@ANALITIC \(endpoint.rawValue) status code: \(statusCode)")
                } else {
                    print("!@ANALITIC ERROR in \(endpoint.rawValue): No status code")
                }
            }
            
            task.resume()
        } catch {
            print("!@ANALITIC ERROR in \(endpoint.rawValue): \(error.localizedDescription)")
        }
    }
}

