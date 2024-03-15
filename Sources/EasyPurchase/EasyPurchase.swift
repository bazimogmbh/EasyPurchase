//
//  EasyPurchase.swift
//
//
//  Created by Yevhenii Korsun on 24.10.2023.
//

import Foundation
import StoreKit
import SwiftyStoreKit

@MainActor
public final class EasyPurchase: ObservableObject {
    public static let shared = EasyPurchase()
    
    @Published public var isSubscribed: Bool = false
    @Published public var isLifetimeSubscription: Bool = false
    @Published public var offers: [Offer] = []
    @Published public var defaultOffer: Offer?
    @Published public var purchasedProducts = [String]()
    
    private var secretKey: String = ""
    private var lifetimeProductId: String?
    private var defaultOfferId: String?
    private var offerIds = [String]()
    private var allProductIds = [String]()
    private var isSkipPurchaseValidation = false
    
    private init() { }
    
    public func configure(
        appstoreId: String,
        secretKey: String,
        lifetimeProductId: String?,
        defaultOfferId: String,
        offerIds: [String],
        allProductIds: [String],
        isSkipPurchaseValidation: Bool = false
    ) {
        Tracker.configure(with: appstoreId)
        
        self.isSubscribed = (Storage.getFromDefaults(.isSubscribed) ?? false)
        self.isLifetimeSubscription = (Storage.getFromDefaults(.isLifetimeSubscription) ?? false)
        self.purchasedProducts = (Storage.loadAsData(for: .purchasedProducts) ?? [])
        self.secretKey = secretKey
        self.lifetimeProductId = lifetimeProductId
        self.defaultOfferId = defaultOfferId
        self.offerIds = offerIds
        self.allProductIds = allProductIds
        self.isSkipPurchaseValidation = isSkipPurchaseValidation
        
        getProducts()
        completeTransactions()
        
        receiptValidation { _ in
            
        }
    }
    
    private func getProducts() {
        SwiftyStoreKit.retrieveProductsInfo(Set(offerIds)) { result in
            guard result.error == nil else {
                print("EasyPurchase Error: \(String(describing: result.error))")
                return
            }
            
            if !result.retrievedProducts.isEmpty {
                let allProducts = result.retrievedProducts
                for product in allProducts {
                    print("EasyPurchase Product: \(product.localizedTitle), Price: \(product.localizedPrice ?? ""), Description: \(product.localizedDescription)")
                }
                
                DispatchQueue.main.async { [self] in
                    let offers = self.offerIds.compactMap { productId in
                        if let product = allProducts.first(where: { $0.productIdentifier == productId }) {
                            return Offer(productId: productId,
                                         product: product,
                                         isLifetime: productId == self.lifetimeProductId)
                        } else {
                            return nil
                        }
                    }
        
                    self.offers = offers
                    self.defaultOffer = offers.first(where: { $0.productId == self.defaultOfferId }) ?? offers.first
                }
                
                Tracker.updatePurchases(of: allProducts)
            }
            
            for invalidProductID in result.invalidProductIDs {
                print("EasyPurchase Error: Invalid product identifier: \(invalidProductID)")
            }
        }
    }
    
    private func receiptValidation(completion: @escaping (_ receipt: ReceiptInfo?)  -> Void) {
#if DEBUG
        let appleValidator = AppleReceiptValidator(service: .sandbox,
                                                   sharedSecret: secretKey)
#else
        let appleValidator = AppleReceiptValidator(service: .production,
                                                   sharedSecret: secretKey)
#endif
       
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            switch result {
            case .success(let receipt):
                var isPurchased = false
                var isLifetimeSubscription = false
                var purchasedIds = [String]()
                
                // Verify the IAP
                if let productId = self.lifetimeProductId {
                    let iapResult = SwiftyStoreKit.verifyPurchase(productId: productId, inReceipt: receipt)
                    
                    switch iapResult {
                    case .purchased(let item):
                        isPurchased = true
                        isLifetimeSubscription = true
                        purchasedIds.append(item.productId)
                    case .notPurchased:
                        print("EasyPurchase Lifetime is not Purchased")
                    }
                }
                
                // Verify the subscriptions
                let subscriptionResult = SwiftyStoreKit.verifySubscriptions(
                    ofType: .autoRenewable,
                    productIds: Set(self.allProductIds),
                    inReceipt: receipt
                )
                
                switch subscriptionResult {
                case .purchased(let expiryDate, let items):
                    isPurchased = true
                    purchasedIds.append(contentsOf: items.map(\.productId))
                    print("EasyPurchase Product is valid until \(expiryDate)\n")
                case .notPurchased:
                    print("EasyPurchase Product is not Purchased")
                case .expired(let expiryDate, _):
                    print("EasyPurchase Product is expired since \(expiryDate)\n")
                }
                
                DispatchQueue.main.async {
                    self.setUser(isPurchased, isLifetimeSubscription: isLifetimeSubscription, purchasedProducts: purchasedIds)
                    completion(receipt)
                }
                
            case .error(let error):
                print("EasyPurchase Error: Receipt verification failed: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    private func setUser(_ isSubscribed: Bool, isLifetimeSubscription: Bool, purchasedProducts: [String]) {
        Storage.saveInDefaults(isSubscribed, by: .isSubscribed)
        Storage.saveInDefaults(isLifetimeSubscription, by: .isLifetimeSubscription)
        Storage.saveInDefaults(purchasedProducts, by: .purchasedProducts)
        
        self.isSubscribed = isSubscribed
        self.isLifetimeSubscription = isLifetimeSubscription
        self.purchasedProducts = purchasedProducts
    }

    private func completeTransactions() {
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                case .failed, .purchasing, .deferred: break
                @unknown default: break
                }
            }
        }
    }
}

// MARK: - Restore

public extension EasyPurchase {
    enum RestoreResultsState {
        case restored
        case failed(Error?)
    }
    
    func restorePurchasesWithResult() async -> RestoreResultsState {
        await withCheckedContinuation { continuation in
            restorePurchasesWithResult { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    func restorePurchasesWithResult(completion: @escaping (_ result: RestoreResultsState) -> Void) {
        restorePurchase { success, message in
            completion(success ? .restored : .failed(message))
        }
    }
    
    func restorePurchases() async -> (success: Bool, message: String) {
        await withCheckedContinuation { continuation in
            restorePurchase { success, message in
                continuation.resume(returning: (success, message))
            }
        }
    }

    func restorePurchase(completion: @escaping (_ success: Bool, _ message: String) -> Void) {
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            if results.restoreFailedPurchases.count > 0 {
                DispatchQueue.main.async {
                    completion(false, "Restore Failed"~)
                }
            } else if results.restoredPurchases.count > 0 {
                self.receiptValidation { (receipt) in
                    DispatchQueue.main.async {
                        let success = receipt != nil
                        completion(success, success ? "Restore is successful"~ : "Nothing to Restore"~)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Nothing to Restore"~)
                }
            }
        }
    }
}

// MARK: - Purchase

public extension EasyPurchase {
    enum PurchaseResultsState {
        case cancelled
        case purchased
        case restored
        case pending
        case failed(Error)
    }
    
    func purchase(product: SKProduct) async -> PurchaseResultsState {
        await withCheckedContinuation { continuation in
            purchase(product.productIdentifier) { result, _, _ in
                continuation.resume(returning: result)
            }
        }
    }
    
    func purchase(_ offer: Offer) async -> (success: Bool, message: String) {
        await purchase(offer.productId)
    }
    
    func purchase(_ productId: String) async -> (success: Bool, message: String) {
        await withCheckedContinuation { continuation in
            purchase(productId) { _, success, message in
                continuation.resume(returning: (success, message))
            }
        }
    }
    
    func purchase(_ offer: Offer, completion: @escaping (_ success: Bool, _ message: String)  -> Void) {
        purchase(offer.productId, completion: completion)
    }
    
    func purchase(_ productId: String, completion: @escaping (_ success: Bool, _ message: String)  -> Void) {
        purchase(productId) { _, success, message in
            completion(success, message)
        }
    }
    
    private func purchase(_ productId: String, completion: @escaping (_ result: PurchaseResultsState, _ success: Bool, _ message: String)  -> Void) {
        print("EasyPurchase purchasing product with id: \(productId)")
        
#if DEBUG
        if isSkipPurchaseValidation {
            setUser(true, isLifetimeSubscription: false, purchasedProducts: [])
            completion(.purchased, true, "Purchase Succeeded"~)
            return
        }
#endif
        
        SwiftyStoreKit.purchaseProduct(productId, quantity: 1, atomically: true) { result in
            switch result {
            case .success(let details):
                self.receiptValidation { (receipt) in
                    Tracker.trackPurchase(details, with: receipt)
                    
                    DispatchQueue.main.async {
                        let success = receipt != nil
                        if success {
                            completion(.purchased, success, "Purchase Succeeded"~)
                        } else {
                            completion(.failed("Recipient Validation Failed"~), success, "Recipient Validation Failed"~)
                        }
                    }
                }
                
            case .deferred(purchase: _):
                DispatchQueue.main.async {
                    completion(.pending, false, "Your purchase is pending approval"~)
                }
                
            case .error(let error):
                DispatchQueue.main.async {
                    completion(.failed(error), false, error.errorMessage)
                }
            }
        }
    }
}

fileprivate extension SKError {
    var errorMessage: String {
        switch self.code {
        case .unknown: return "Unknown error. Please contact support"
        case .clientInvalid: return "Not allowed to make the payment"
        case .paymentCancelled: return "Payment cancelled"
        case .paymentInvalid: return "The purchase identifier was invalid"
        case .paymentNotAllowed: return "The device is not allowed to make the payment"
        case .storeProductNotAvailable: return "The product is not available in the current storefront"
        case .cloudServicePermissionDenied: return "Access to cloud service information is not allowed"
        case .cloudServiceNetworkConnectionFailed: return "Could not connect to the network"
        case .cloudServiceRevoked: return "User has revoked permission to use this cloud service"
        default: return (self as NSError).localizedDescription
        }
    }
}

extension String: Error {
    
}
