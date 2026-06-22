//
//  TTIAPTransactionEventRouter+SK1.swift
//  TikTokBusinessSDK
// 
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.
    
import StoreKit

// MARK: TTIAPTransactionEventRouter API for SK1
@available(iOS 15.0, *)
extension TTIAPTransactionEventRouter {
    func routeSK1(_ transaction: SKPaymentTransaction) async {
        let fetcher = TTSK1ProductFetcher()
        let product = await fetcher.product(for: transaction.payment.productIdentifier)
        let eventName = Self.eventName(transaction)
        let transactionId: String = transaction.transactionIdentifier ?? ""
        guard let eventName, let product else {
            return
        }
        
        if await TTIAPTransactionCacheManager.shared.cacheContains(transactionId: transactionId, productId: product.productIdentifier, eventName: eventName) {
            return
        }
        
        await TTIAPTransactionCacheManager.shared.cache(transactionId: transactionId, productId: product.productIdentifier, eventName: eventName)
        
        let totalAmount: Double = Double(transaction.payment.quantity) * product.price.doubleValue
        
        var eventParams = Self.eventParams(transaction, product: product)
        eventParams.updateValue(String(totalAmount), forKey: "value")
        eventParams["storekit_version"] = 1
        let event = TikTokBaseEvent.init(eventName: eventName, properties: eventParams, eventId: "")
        TikTokBusiness.trackTTEvent(event)
        
        if TikTokBusiness.isPayShowTrackEnabled {
            eventParams.updateValue("enhanced_data_postback", forKey: "monitor_type")
            TikTokBusiness.trackTTEvent(.init(eventName: "pay_show", properties: eventParams, eventId: ""))
        }
        logger.debugMessage("SK1 track event: \(eventName), properties: \(eventParams)")
    }
    
    static func eventName(_ transaction: SKPaymentTransaction) -> String? {
        switch transaction.transactionState {
        case .purchasing:
            return "Purchasing"
        case .purchased:
            return "Purchase"
        case .failed:
            return "PurchaseFailed"
        case .restored:
            return "PurchaseRestored"
        case .deferred:
            return "PurchaseDeferred"
        @unknown default:
            return nil
        }
    }
    
    static func eventParams(_ transaction: SKPaymentTransaction, product: SKProduct) -> [String: Any] {
        var eventParameters: [String: Any] = [:]
        let transactionId = transaction.transactionIdentifier
        let originalTransactionId = transaction.original?.transactionIdentifier
        let payment = transaction.payment
        
        // order
        let orderInfo = ["order_id": transactionId ?? "",
                         "original_transaction_id": originalTransactionId ?? "",
                         "order_time": Date.currentTimeStampString()]
        eventParameters.updateValue(orderInfo, forKey: "order")
        
        eventParameters.updateValue(product.priceLocale.currencyCode ?? "", forKey: "currency")
        eventParameters.updateValue("", forKey: "query")
        eventParameters.updateValue(transaction.transactionState.rawValue, forKey: "code")
        eventParameters.updateValue("auto", forKey: "type")
        
        // contents
        var contents:[[String: Any]] = []
        // basic product info
        var productDict: [String: Any] = [:]
        let contentType = product.subscriptionPeriod != nil ? "SUB" : "SKU"
        productDict.updateValue(String(product.price.doubleValue), forKey: "price")
        productDict.updateValue(String(payment.quantity), forKey: "quantity")
        productDict.updateValue(contentType, forKey: "content_type")
        productDict.updateValue(product.localizedDescription, forKey: "description")
        productDict.updateValue(product.localizedTitle, forKey: "title")
        // subscription info
        if let subscriptionPeriod = product.subscriptionPeriod {
            productDict.updateValue(subscriptionPeriodInDays(subscriptionPeriod), forKey: "subscription_period")
            productDict.updateValue(subscriptionPeriod.numberOfUnits, forKey: "subscription_period_number")
            productDict.updateValue(product.price.stringValue, forKey: "recurring_price")
            if let discount = product.discounts.first, discount.paymentMode == .freeTrial {
                productDict.updateValue(daysFromPeriodUnit(discount.subscriptionPeriod.unit), forKey: "free_trial_period")
            }
        }
        // discount info
        if product.discounts.isEmpty == false {
            var discountsArr: [[String: Any]] = []
            for discount in product.discounts {
                var discountInfo: [String: Any] = [:]
                discountInfo.updateValue(discount.identifier ?? "", forKey: "offer_id")
                let discountType = discount.type == .introductory ? "Introductory" : "Subscription"
                discountInfo.updateValue(discountType, forKey: "type")
                discountInfo.updateValue(discount.price.stringValue, forKey: "price")
                discountInfo.updateValue(stringOfPaymentMode(discount.paymentMode), forKey: "payment_mode")
                discountInfo.updateValue(subscriptionPeriodInDays(discount.subscriptionPeriod), forKey: "discount_period")
                discountInfo.updateValue(discount.subscriptionPeriod.numberOfUnits, forKey: "discount_period_number")
                discountsArr.append(discountInfo)
            }
            productDict.updateValue(discountsArr, forKey: "offers")
        }
        productDict.updateValue(product.productIdentifier, forKey: "content_id")
        contents.append(productDict)
        
        eventParameters.updateValue(contents, forKey: "contents")
        return eventParameters
    }
    
    static func subscriptionPeriodInDays(_ period: SKProductSubscriptionPeriod) -> Int {
        if period.numberOfUnits == 0 {
            return 0
        }
        return period.numberOfUnits * daysFromPeriodUnit(period.unit)
    }
    
    static func daysFromPeriodUnit(_ unit: SKProduct.PeriodUnit) -> Int {
        switch unit {
        case .day:
            return 1
        case .week:
            return 7
        case .month:
            return 30
        case .year:
            return 365
        @unknown default:
            return 0
        }
    }
    
    static func stringOfPaymentMode(_ paymentMode: SKProductDiscount.PaymentMode) -> String {
        switch paymentMode {
        case .payAsYouGo:
            return "pay_as_you_go"
        case .payUpFront:
            return "pay_up_front"
        case .freeTrial:
            return "free_trial"
        @unknown default:
            return ""
        }
    }
}
