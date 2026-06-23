//
//  TTIAPTransactionCacheManager.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/4.
//  Copyright © 2026 TikTok. All rights reserved.
    
import Foundation

fileprivate let TTIAP_TRANSACTION_CACHE_KEY: String = "TTIAP_TRANSACTION_CACHE_KEY"

fileprivate let TTIAP_TRANSACTION_CHECK_DATE_KEY: String = "TTIAP_TRANSACTION_CHECK_DATE_KEY"

@available(iOS 15.0, *)
final actor TTIAPTransactionCacheManager {
    
    fileprivate struct CacheModel: Codable, Hashable, Equatable {
        let transactionId: String
        let productId: String
        let eventName: String
        let date: Date
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(transactionId)
            hasher.combine(productId)
            hasher.combine(eventName)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.transactionId == rhs.transactionId
            && lhs.productId == rhs.productId && lhs.eventName == rhs.eventName
        }
    }
    
    static let shared = TTIAPTransactionCacheManager()
    
    private(set) var lastCheckedDate: Date {
        didSet {
            UserDefaults.tiktokBusiness.set(lastCheckedDate, forKey: TTIAP_TRANSACTION_CHECK_DATE_KEY)
        }
    }
    
    private var cachedTransactions: Set<CacheModel>
    
    init() {
        let data = UserDefaults.tiktokBusiness.data(forKey: TTIAP_TRANSACTION_CACHE_KEY)
        if let data, let caches = try? JSONDecoder().decode(Set<CacheModel>.self, from: data) {
            cachedTransactions = caches
        } else {
            cachedTransactions = []
        }
        lastCheckedDate = UserDefaults.tiktokBusiness.value(forKey: TTIAP_TRANSACTION_CHECK_DATE_KEY) as? Date ?? Date()
    }
    
    private func save() {
        clearExpiredCache()
        guard
            cachedTransactions.isEmpty == false,
            let data = try? JSONEncoder().encode(cachedTransactions)
        else {
            return
        }
        UserDefaults.tiktokBusiness.set(data, forKey: TTIAP_TRANSACTION_CACHE_KEY)
    }
    
    private func clearExpiredCache() {
        guard cachedTransactions.isEmpty == false else {
            return
        }
        let earlierDate = Date.init(timeInterval: -60 * 60 * 24 * 30, since: Date())    // 清除 30 天前的数据
        cachedTransactions = cachedTransactions.filter({ cache in
            return cache.date >= earlierDate
        })
    }
}

// MARK: Internal
@available(iOS 15.0, *)
extension TTIAPTransactionCacheManager {
    
    func updateCheckedDate(_ date: Date) {
        lastCheckedDate = date
    }
    
    func cache(transactionId: String, productId: String, eventName: String) {
        guard transactionId.isEmpty == false, productId.isEmpty == false else {
            return
        }
        
        cachedTransactions.insert(.init(transactionId: transactionId, productId: productId, eventName: eventName, date: Date()))
        
        save()
    }
    
    func cacheContains(transactionId: String, productId: String, eventName: String) -> Bool {
        guard transactionId.isEmpty == false, productId.isEmpty == false else {
            return false
        }
        
        if cachedTransactions.contains(.init(transactionId: transactionId, productId: productId, eventName: eventName, date: Date())) {
            return true
        }
        return false
    }
}
