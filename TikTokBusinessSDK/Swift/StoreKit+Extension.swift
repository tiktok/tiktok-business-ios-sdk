//
//  StoreKit+Extension.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/5/21.
//  Copyright © 2026 TikTok. All rights reserved.
    
import StoreKit

@available(iOS 15.0, *)
extension Product.SubscriptionPeriod {
    func days() -> Int {
        switch unit {
            case .day:   return value
            case .week:  return value * 7
            case .month: return value * 30
            case .year:  return value * 365
            @unknown default: return value * 30
        }
    }
}

@available(iOS 15.0, *)
extension Product.SubscriptionOffer.PaymentMode {
    func typeString() -> String {
        switch self {
        case .freeTrial:
            return "free_trial"
        case .payAsYouGo:
            return "pay_as_you_go"
        case .payUpFront:
            return "pay_up_front"
        default:
            return ""
        }
    }
}
