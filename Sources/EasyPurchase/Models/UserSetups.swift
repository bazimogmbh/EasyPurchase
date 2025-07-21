//
//  UserSetups.swift
//
//
//  Created by Yevhenii Korsun on 23.10.2023.
//

import Foundation

struct UserSetups: DictionaryConvertable {
    var attribution: Bool? = nil
    var campaignId: String? = nil
    var campaignRegion: String? = nil
    let appBundleId: String?
    let appUserId: String?
    let idfa: String?
    let vendorId: String?
    let appVersion: String?
    let appstoreId: String?
    let iosVersion: String?
    let device: String?
    let locale: String?
    let countryCode: String?
    
    var attributionRecords: AttributionRecords? = nil
}

extension UserSetups {
    struct AttributionRecords: DictionaryConvertable {
        let attribution: Bool
        let campaignId: Int
        let countryOrRegion: String
        
        let orgId: Int?
        let adGroupId: Int?
        let conversionType: String?
        let clickDate: String?
        let keywordId: Int?
        let creativeSetId: Int?
        let keywordName: String?
        let organizationId: Int?
        let region: String?
        let campaignName: String?
        let adGroupName: String?
    }
}
