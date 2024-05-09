//
//  Tracker.swift
//
//
//  Created by Yevhenii Korsun on 24.10.2023.
//

import Foundation
import AppTrackingTransparency
import AdSupport
import Network
import StoreKit
import SwiftyStoreKit

#if !os(tvOS)
import AdServices
#endif

protocol TrackServiceProtocol {
    static func configure(with appstoreId: String)
    static func trackPurchase(_ details: PurchaseDetails, with info: ReceiptInfo?)
    static func updatePurchases(of products: Set<SKProduct>)
}

enum Tracker: TrackServiceProtocol {
    private static let appUserId: String = getUserId()
    private static var idfa: String = ""
    private static var vendorId: String = ""
    private static var isNotConfigure = true
    
#if os(macOS)
    private static var didBecomeActiveNotification = NSApplication.didBecomeActiveNotification
#else
    private static var didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
#endif
    
    static func configure(with appstoreId: String) {
        NotificationCenter.default.addObserver(
            forName: didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            ATTrackingManager.requestTrackingAuthorization { status in
                sendData()
            }
        }
        
        func sendData() {
            guard isNotConfigure else { return }
            isNotConfigure = false
            
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            self.idfa = idfa
            
            self.vendorId = vendorId
            
            var userSetups = UserSetups(
                appBundleId: Bundle.main.bundleIdentifier ?? "",
                appUserId: self.appUserId,
                idfa: idfa,
                vendorId: vendorId,
                appVersion: Bundle.main.appVersion,
                appstoreId: appstoreId,
                iosVersion: systemVersion,
                device: modelName,
                locale: Locale.current.identifier,
                countryCode: Locale.current.countryCode
            )
            
            handleAttribution { param in
                userSetups.attribution = param?.attribution
                userSetups.campaignId = param?.campaignId
                userSetups.campaignRegion = param?.campaignRegion
                send(userSetups, to: .configure)
            }
        }
        
        var vendorId: String {
#if os(macOS)
            CFPreferencesCopyAppValue("VendorIdentifier" as CFString, (Bundle.main.bundleIdentifier ?? "") as CFString) as? String  ?? ""
#else
            UIDevice.current.identifierForVendor?.uuidString ?? ""
#endif
        }
        
        var systemVersion: String {
#if os(macOS)
            let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
            return "\(systemVersion.majorVersion).\(systemVersion.minorVersion).\(systemVersion.patchVersion)"
#else
            UIDevice.current.systemVersion
#endif
        }
    }
    
    static func trackPurchase(_ details: PurchaseDetails, with info: ReceiptInfo?) {
        guard let info else { return }
        
        let result = SwiftyStoreKit.verifyPurchase(productId: details.productId, inReceipt: info)
        if case .purchased(let item) = result {
            var token = ""
            
            if let url = Bundle.main.appStoreReceiptURL,
               let data = try? Data(contentsOf: url) {
                token = data.base64EncodedString()
                
            }
            
            let expirationAtMs: String? = {
                if let expirationDate = item.subscriptionExpirationDate {
                    return String(expirationDate.milliseconds)
                }
                
                return nil
            }()
            
            let purchaseDetail = PurchaseDetail(
                appBundleId: Bundle.main.bundleIdentifier ?? "",
                appUserId: self.appUserId,
                productId: details.product.productIdentifier,
                transactionId: details.transaction.transactionIdentifier ?? "",
                token: token,
                priceInPurchasedCurrency: details.product.price.stringValue,
                currency: details.product.priceLocale.currencyCode ?? "",
                purchasedAtMs: String(details.originalPurchaseDate.milliseconds),
                expirationAtMs: expirationAtMs,
                withTrial: details.product.introductoryPrice != nil
            )
            
            send(purchaseDetail, to: .trackPurchase)
        }
    }
    
    static func updatePurchases(of products: Set<SKProduct>) {
        let isFirstRun: Bool = Storage.getFromDefaults(.isFirstRun) ?? true
        print("!@ANALITIC Old Purchases prepeare: \(isFirstRun)")
        
        if isFirstRun {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { // need to restorePurchases work correct
                print("!@ANALITIC Old Purchases start")
                
                SwiftyStoreKit.restorePurchases { results in
                    Storage.saveInDefaults(false, by: .isFirstRun)
                    print("!@ANALITIC Old Purchases \(results.restoredPurchases)")
                    
                    let allPurchaseDetail = AllPurchaseDetail(purchases: results.restoredPurchases.map { purchase in
                        let product = product(by: purchase.productId)
                        let expirationAtMs: String? = {
                            if let subscriptionPeriod = product?.subscriptionPeriod?.milliseconds {
                                return String(purchase.originalPurchaseDate.milliseconds + subscriptionPeriod)
                            }
                            
                            return nil
                        }()
                        
                        return PurchaseDetail(appBundleId: Bundle.main.bundleIdentifier ?? "",
                                              appUserId: self.appUserId,
                                              productId: purchase.productId,
                                              transactionId: purchase.originalTransaction?.transactionIdentifier ?? "",
                                              token: nil,
                                              priceInPurchasedCurrency: product?.price.stringValue ?? "",
                                              currency: product?.priceLocale.currencyCode ?? "",
                                              purchasedAtMs: String(purchase.originalPurchaseDate.milliseconds),
                                              expirationAtMs: expirationAtMs,
                                              withTrial: product?.introductoryPrice != nil
                        )
                    }
                    )
                    
                    send(allPurchaseDetail, to: .trackAllPurchases)
                }
            }
        }
        
        func product(by productId: String) -> SKProduct? {
            products.first(where: { $0.productIdentifier == productId })
        }
    }
    
   private static func handleAttribution(completion: @escaping ((attribution: Bool,
                                                          campaignId: String,
                                                          campaignRegion: String)?) -> Void
   ) {
       
#if targetEnvironment(simulator)
       completion(nil)
#else
       getAttribution()
#endif
       
       func getAttribution() {
           var attributionToken: String?
           
#if !os(tvOS)
           attributionToken = try? AAAttribution.attributionToken()
#endif
           
           if let attributionToken {
               DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                   let request = NSMutableURLRequest(url: URL(string:"https://api-adservices.apple.com/api/v1/")!)
                   request.httpMethod = "POST"
                   request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                   request.httpBody = Data(attributionToken.utf8)
                   
                   let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
                       if let data,
                          let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:Any],
                          let attribution = result["attribution"] as? Bool,
                          let campaignId = result["campaignId"] as? Int,
                          let countryOrRegion = result["countryOrRegion"] as? String,
                          campaignId != 1234567890 {
                           completion((attribution: attribution,
                                       campaignId: "\(campaignId)",
                                       campaignRegion: countryOrRegion))
                       }
                       
                       completion(nil)
                   }
                   
                   task.resume()
               }
           } else {
               completion(nil)
           }
       }
    }
}

// MARK: - Helpers

extension Tracker {
    static private func send<T: DictionaryConvertable>(_ data: T, to endpoint: NetworkService.TrackerEndpoint) {
        NetworkService.send(data, endpoint: endpoint)
    }
    
    static private func getUserId() -> String {
        if let appUserId: String = Storage.getFromDefaults(.appUserId) {
            return appUserId
        } else {
            let appUserId = "\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
            Storage.saveInDefaults(appUserId, by: .appUserId)
            Storage.saveInDefaults(true, by: .isFirstRun)
            return appUserId
        }
    }
}

fileprivate extension Date {
    var milliseconds: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}

fileprivate extension SKProductSubscriptionPeriod {
    var milliseconds: Int64? {
        let milisecondsInDay: Double = 24 * 60 * 60 * 1000
        var result: Double = 0
        
        switch self.unit {
        case .day:
            result = TimeInterval(self.numberOfUnits) * milisecondsInDay
        case .week:
            result = TimeInterval(self.numberOfUnits) * 7 * milisecondsInDay
        case .month:
            result = TimeInterval(self.numberOfUnits) * 30 * milisecondsInDay
        case .year:
            result = TimeInterval(self.numberOfUnits) * 365 * milisecondsInDay
        @unknown default:
            return nil
        }
        
        return Int64(result)
    }
}

fileprivate extension Tracker {
   static var modelName: String {
#if targetEnvironment(simulator)
        let identifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Name not found"
#else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
#endif
        return identifier
    }
}

fileprivate extension Bundle {
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Could not determine the application name"
    }
    
    var appBuild: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Could not determine the application build number"
    }
    
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Could not determine the application version"
    }
}

fileprivate extension Locale {
    var countryCode: String {
        if #available(iOS 16, macOS 13, *) {
            return self.language.region?.identifier ?? ""
        } else {
            return self.regionCode  ?? ""
        }
    }
}

//#endif
