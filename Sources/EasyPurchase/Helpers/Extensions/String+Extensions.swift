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

extension String {
    func localize(with arguments: [CVarArg]) -> String {
        return String(format: self, locale: nil, arguments: arguments)
    }
}
