//
//  TTStoreKitObserver+SK1.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.

import StoreKit

@available(iOS 15.0, *)
extension TTStoreKitObserver: SKPaymentTransactionObserver {
    
    func startObserveStoreKit1() {
        debugMessage("start SK1 observe.")
        SKPaymentQueue.default().add(self)
    }
    
    func stopObserveStoreKit1() {
        debugMessage("stop SK1 observe.")
        SKPaymentQueue.default().remove(self)
    }
    
    nonisolated public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        Task.detached {
            for transaction in transactions {
                await self.debugMessage("SK1 paymentQueue received transaction. product id: \(transaction.payment.productIdentifier)")
                let extraParams = await self.extraParams
                let router = TTIAPTransactionEventRouter(extraParams: extraParams)
                await router.routeSK1(transaction)
            }
        }
    }
}
