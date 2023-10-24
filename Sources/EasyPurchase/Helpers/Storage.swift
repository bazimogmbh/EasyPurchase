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
    }
    
    static func saveInDefaults(_ value: Any?, by key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue + "EasyPurchase")
    }
    
    static func getFromDefaults<T>(_ key: DefaultsKey) -> T? {
        return UserDefaults.standard.value(forKey: key.rawValue + "EasyPurchase") as? T
    }
}
