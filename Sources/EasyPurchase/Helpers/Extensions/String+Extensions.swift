//
//  String+Extensions.swift
//
//
//  Created by Yevhenii Korsun on 24.10.2023.
//

import Foundation

postfix operator ~
extension String.LocalizationValue {
    static postfix func ~(string: String.LocalizationValue) -> String {
        String(localized: string)
    }
}
