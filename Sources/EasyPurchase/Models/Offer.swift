//
//  Offer.swift
//  
//
//  Created by Yevhenii Korsun on 24.10.2023.
//

import Foundation
import StoreKit
import SwiftyStoreKit

public struct Offer: Equatable, Identifiable {
    public var id: String {
        productId
    }
    
    public private(set) var productId: String
    public private(set) var product: SKProduct?
    public private(set) var isLifetime: Bool = false
    
    public init(productId: String, product: SKProduct, isLifetime: Bool = false) {
        self.productId = productId
        self.product = product
        self.isLifetime = isLifetime
    }
    
    init(productId: String) {
        self.productId = productId
    }
}

public extension Offer {
    static func dummy(with productId: String) -> Offer {
        Offer(productId: productId)
    }
}

public extension Offer {
    var period: String {
        localize(product?.subscriptionPeriod) ?? ""
    }
    
    var localizedPrice: String? {
        product?.localizedPrice
    }
    
    var priceInDouble: Double? {
        product?.price.doubleValue
    }
    
    var trialPeriodNumber: Int? {
        product?.introductoryPrice?.subscriptionPeriod.numberOfUnits
    }
    
    var trialPeriod: String? {
        localize(product?.introductoryPrice?.subscriptionPeriod)
    }
    
    private var days: Int? {
        guard let product,
              let duration = product.subscriptionPeriod?.numberOfUnits,
              let days: Int = {
                  switch product.subscriptionPeriod?.unit {
                  case .day: return 1
                  case .week: return 7
                  case .month: return 30
                  case .year: return 365
                  default: return nil
                  }
              }()
        else {
            return nil
        }
        
        return duration * days
    }
    
    func discount(to baseOffer: Offer) -> Int? {
        guard let baseOfferDays = baseOffer.days,
              let selfDays = self.days,
              let selfPriceInDouble = self.priceInDouble,
              let baseOfferPriceInDouble = baseOffer.priceInDouble
        else {
            return nil
        }
        
        let discount = 1.0 - (selfPriceInDouble / Double(selfDays)) / (baseOfferPriceInDouble / Double(baseOfferDays))
        return Int(discount * 100.0)
    }
    
    private func localize(_ period: SKProductSubscriptionPeriod?) -> String? {
        guard let period else { return nil }
        
        let unit = period.unit
        let numberOfUnits: Int = period.numberOfUnits
        
        var localizedPeriod = {
            switch unit {
            case .day: "\(numberOfUnits) days"~
            case .week: "\(numberOfUnits) weeks"~
            case .month: "\(numberOfUnits) months"~
            case .year: "\(numberOfUnits) years"~
            default: "lifetime"~
            }
        }()

        return localizedPeriod
    }
}
