//
//  TTIAPTransactionEventRouter+SK2.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.

import StoreKit

// MARK: TTIAPTransactionEventRouter API for SK2
@available(iOS 15.0, *)
extension TTIAPTransactionEventRouter {
    func routeSK2(_ transaction: Transaction?, productId: String, isRestored: Bool = false) async {
        var transactionId: String = ""
        var originalTransactionId: String = ""
        if let transaction {
            transactionId = String(transaction.id)
            originalTransactionId = String(transaction.originalID)
        }
        let product = try? await Product.products(for: [productId]).first
        guard let product else {
            return
        }
        let eventName = Self.eventName(transaction, isRestored: isRestored)
        
        if await TTIAPTransactionCacheManager.shared.cacheContains(transactionId: transactionId, productId: productId, eventName: eventName) {
            return
        }
        
        await TTIAPTransactionCacheManager.shared.cache(transactionId: transactionId, productId: productId, eventName: eventName)
        
        let code = Self.eventCode(transaction)
        let value = Double(transaction?.purchasedQuantity ?? 1) * NSDecimalNumber(decimal: product.price).doubleValue
        
        var eventParams: [String: Any] = [:]
        eventParams.updateValue(String(value), forKey: "value")
        eventParams.updateValue(code, forKey: "code")
        eventParams.updateValue("", forKey: "query")
        eventParams.updateValue("auto", forKey: "type")
        eventParams.updateValue(Self.eventOrderInfo(transactionId, originalID: originalTransactionId), forKey: "order")
        
        eventParams["contents"] = Self.eventContents(transaction, product: product)
        eventParams["storekit_version"] = 2
        
        if let transaction {
            if #available(iOS 16.0, *) {
                eventParams["currency"] = transaction.currency?.identifier ?? ""
            } else {
                eventParams["currency"] = transaction.currencyCode
            }
            let jsonString = String.init(data: transaction.jsonRepresentation, encoding: .utf8)
            eventParams["original_json"] = jsonString
        } else {
            eventParams["currency"] = product.priceFormatStyle.currencyCode
        }
        
        logger.debugMessage("SK2 track event: \(eventName), properties: \(eventParams)")
        TikTokBusiness.trackTTEvent(.init(eventName: eventName, properties: eventParams, eventId: ""))
        
        if TikTokBusiness.isPayShowTrackEnabled {
            eventParams["monitor_type"] = "enhanced_data_postback"
            TikTokBusiness.trackTTEvent(.init(eventName: "pay_show",
                                              properties: eventParams,
                                              eventId: ""))
        }
    }
    
    static func eventName(_ transaction: Transaction?, isRestored: Bool) -> String {
        guard let transaction else {
            return "PurchaseFailed"
        }
        if isRestored {
            return "PurchaseRestored"
        }
        
        if transaction.revocationReason == .developerIssue || transaction.revocationReason == .other {
            return "PurchaseFailed"
        }
        
        // not revocated, purchase success
        return "Purchase"
    }
    
    static func eventCode(_ transaction: Transaction?) -> Int {
        guard let transaction else {
            return 2
        }
        if transaction.revocationReason != nil {
            // fail
            return 2
        }
        // success
        return 1
    }
    
    static func eventOrderInfo(_ transactionId: String, originalID: String) -> [String: Any] {
        var orderInfo = [String: Any]()
        orderInfo["order_id"] = transactionId
        orderInfo["original_transaction_id"] = originalID
        orderInfo["order_time"] = Date.currentTimeStampString()
        return orderInfo
    }
    
    static func eventContents(_ transaction: Transaction?, product: Product) -> [[String: Any]] {
        var dict: [String: Any] = [:]
        let quantity = Decimal(transaction?.purchasedQuantity ?? 1)
        let unitPrice = product.price
        dict["price"] = String(describing:unitPrice)
        dict["quantity"] = String(describing:quantity)
        dict["content_id"] = product.id
        dict["title"] = product.displayName
        dict["description"] = product.description

        if let subscription = product.subscription {
            dict["content_type"] = "SUB"
            let period = subscription.subscriptionPeriod
            dict["subscription_period"] = period.days()
            dict["subscription_period_number"] = period.value
            dict["recurring_price"] = String(describing:unitPrice)
        } else {
            dict["content_type"] = "SKU"
        }
        
        if #available(iOS 18.4, *) {
            if let offer = transaction?.offer {
                if offer.paymentMode == .freeTrial, let priod = offer.period {
                    let freeTrialPeriod = priod.days()
                    dict["free_trial_period"] = freeTrialPeriod
                }
            }
        }
        
        var subscriptionOffsers: [Product.SubscriptionOffer] = []
        if let offer = product.subscription?.introductoryOffer {
            subscriptionOffsers.append(offer)
        }
        if let offers = product.subscription?.promotionalOffers {
            subscriptionOffsers.append(contentsOf: offers)
        }
        if #available(iOS 18.0, *) {
            if let offers = product.subscription?.winBackOffers {
                subscriptionOffsers.append(contentsOf: offers)
            }
        }
        var discounts: [[String: Any]] = []
        for offser in subscriptionOffsers {
            var discountInfo = [String: Any]()
            discountInfo["offer_id"] = offser.id ?? ""
            discountInfo["type"] = offser.type == .introductory ? "Introductory" : "Subscription"
            discountInfo["price"] = NSDecimalNumber(decimal: offser.price).stringValue
            discountInfo["payment_mode"] = offser.paymentMode.typeString()
            discountInfo["discount_period"] = offser.period.days()
            discountInfo["discount_period_number"] = offser.period.value
            discounts.append(discountInfo)
        }

        return [dict]
    }
}
