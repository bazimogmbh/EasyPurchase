//
//  String+Extensions.swift
//
//
//  Created by Yevhenii Korsun on 24.10.2023.
//

import Foundation

postfix operator ~
//postfix func ~(string: String) -> String {
//    return NSLocalizedString(string, bundle: Bundle(for: EasyPurchase.self), comment: "")
//}

extension String.LocalizationValue {
    static postfix func ~(string: String.LocalizationValue) -> String {
        String(localized: string, bundle: Bundle(for: EasyPurchase.self))
    }
}
