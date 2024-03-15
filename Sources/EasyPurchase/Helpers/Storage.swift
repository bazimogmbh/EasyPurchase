//
//  Storage.swift
//
//
//  Created by Yevhenii Korsun on 24.10.2023.
//

import Foundation

enum Storage {
    enum DefaultsKey: String {
        case appUserId
        case isFirstRun
        case isSubscribed
        case isLifetimeSubscription
        case purchasedProducts
    }
    
    static func saveInDefaults(_ value: Any?, by key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue + "EasyPurchase")
    }
    
    static func getFromDefaults<T>(_ key: DefaultsKey) -> T? {
        return UserDefaults.standard.value(forKey: key.rawValue + "EasyPurchase") as? T
    }
    
    static func saveAsData<T: Codable>(_ value: T, for key: DefaultsKey) {
        let data = try? JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key.rawValue)
    }
    
    static func loadAsData<T: Codable>(for key: DefaultsKey) -> T? {
        guard let data = UserDefaults.standard.object(forKey: key.rawValue) as? Data else {
            return nil
        }
        
        let value = try? JSONDecoder().decode(T.self, from: data)
        return value
    }
}
