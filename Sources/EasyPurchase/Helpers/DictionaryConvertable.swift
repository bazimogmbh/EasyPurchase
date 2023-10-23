//
//  DictionaryConvertable.swift
//
//
//  Created by Yevhenii Korsun on 23.10.2023.
//

import Foundation

protocol DictionaryConvertable: DictionaryDecodable {
    func toDictionary() -> [String: Any]
}

protocol DictionaryDecodable: Decodable {
    static func decode(from dictionary: [AnyHashable: Any]) throws -> Self
}

extension DictionaryDecodable {
    static func decode(from dictionary: [AnyHashable: Any]) throws -> Self {
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let decoder = JSONDecoder()
        let object = try decoder.decode(Self.self, from: jsonData)
        return object
    }
}

protocol EnumConvertable {
    init?(rawValue: String)
    var rawValue: String { get }
}

extension DictionaryConvertable {
    func toDictionary() -> [String: Any] {
        let reflect = Mirror(reflecting: self)
        let children = reflect.children
        let dictionary = toAnyHashable(elements: children)
        return dictionary
    }
    
    func toAnyHashable(elements: AnyCollection<Mirror.Child>) -> [String : Any] {
        var dictionary: [String : Any] = [:]
        for element in elements {
            if let camelCaseKey = element.label {
               let key = convertCamelCaseToSnakeCase(camelCaseKey)

                if let collectionValidHashable = element.value as? [AnyHashable] {
                    dictionary[key] = collectionValidHashable
                }
                
                if let validHashable = element.value as? AnyHashable {
                    dictionary[key] = validHashable
                }
                
                if let convertor = element.value as? DictionaryConvertable {
                    dictionary[key] = convertor.toDictionary()
                }
                
                if let convertorList = element.value as? [DictionaryConvertable] {
                    dictionary[key] = convertorList.map({ e in
                       return e.toDictionary()
                    })
                }
                
                if let validEnum = element.value as? EnumConvertable {
                    dictionary[key] = validEnum.rawValue
                }
            }
        }
        return dictionary
        
        func convertCamelCaseToSnakeCase(_ input: String) -> String {
            return input.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1_$2", options: .regularExpression, range: nil).lowercased()
        }
    }
}

