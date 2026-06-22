//
//  TTStoreKitObserver+SK2.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.
    
import StoreKit

@available(iOS 15.0, *)
extension TTStoreKitObserver {
    
    func startObserveStoreKit2() {
        guard pollingTask == nil else { return }
        debugMessage("start SK2 observe.")
        pollingTask = Task.detached { [weak self] in
            guard let self = self else { return }
            
            await self.handleInitialTransactions()
            
            while !Task.isCancelled {
                await self.debugMessage("fetchNewTransactions.")
                await self.fetchNewTransactions()
                
                do {
                    try await Task.sleep(nanoseconds: self.pollInterval * 1_000_000)
                } catch {
                    break
                }
            }
        }
    }
    
    func stopObserveStoreKit2() {
        pollingTask?.cancel()
        pollingTask = nil
        debugMessage("stop SK2 observe.")
    }
    
    fileprivate func handleInitialTransactions() async {
        guard isObserving else { return }
        
        let lastCheckDate = await TTIAPTransactionCacheManager.shared.lastCheckedDate
        var latestTransactionDate: Date = lastCheckDate
        debugMessage("handleInitialTransactions.")
        for await result in Transaction.currentEntitlements {
            guard
                case .verified(let transaction) = result,
                transaction.purchaseDate >= lastCheckDate
            else {
                continue
            }
            if transaction.purchaseDate > latestTransactionDate {
                latestTransactionDate = transaction.purchaseDate
            }
            await handle(transaction: transaction, isRestored: true)
        }

        for await result in Transaction.unfinished {
            guard
                case .verified(let transaction) = result
            else {
                continue
            }
            if transaction.purchaseDate > latestTransactionDate {
                latestTransactionDate = transaction.purchaseDate
            }
            await handle(transaction: transaction, isRestored: false)
        }
        
        if latestTransactionDate > lastCheckDate {
            await TTIAPTransactionCacheManager.shared.updateCheckedDate(latestTransactionDate)
        }
    }
    
    fileprivate func fetchNewTransactions() async {
        guard isObserving else { return }
        let lastCheckDate = await TTIAPTransactionCacheManager.shared.lastCheckedDate
        var latestTransactionDate: Date = lastCheckDate
        var newTransactions: [Transaction] = []
        do {
            let unfinishedTransactions: [UInt64] = try await Transaction.unfinished.collect().map { result in
                if case .verified(let transaction) = result {
                    return transaction.id
                } else {
                    return 0
                }
            }.filter({ $0 > 0 })
            
            for result in try await Transaction.all.collect() {
                guard case .verified(let transaction) = result else { continue }
                
                if unfinishedTransactions.contains(transaction.id) {
                    continue
                }
                
                if transaction.revocationDate != nil {
                    continue
                }
                
                if let expirationDate = transaction.expirationDate, expirationDate >= Date() {
                    continue
                }
                
                if transaction.purchaseDate > lastCheckDate {
                    newTransactions.append(transaction)
                    
                    if transaction.purchaseDate > latestTransactionDate {
                        latestTransactionDate = transaction.purchaseDate
                    }
                }
            }
        } catch {
            monitorFetchNewTransactionsFailed(error)
        }
        
        newTransactions = newTransactions.sorted(by: { $0.purchaseDate < $1.purchaseDate })
        for transaction in newTransactions {
            await handle(transaction: transaction, isRestored: false)
        }
        
        if latestTransactionDate > lastCheckDate {
            await TTIAPTransactionCacheManager.shared.updateCheckedDate(latestTransactionDate)
        }
    }
    
    fileprivate func handle(transaction: Transaction, isRestored: Bool) async {
        debugMessage("SK2 handle transaction id: \(transaction.id), isRestored: \(isRestored)")
        let router = TTIAPTransactionEventRouter(extraParams: extraParams)
        await router.routeSK2(transaction, productId: transaction.productID)
    }
    
    func handleFailed(_ productId: String) async {
        debugMessage("SK2 handle failed product. id: \(productId)")
        let router = TTIAPTransactionEventRouter(extraParams: extraParams)
        await router.routeSK2(nil, productId: productId)
    }
    
    private func monitorFetchNewTransactionsFailed(_ error: Error) {
        var meta: [String: Any] = [:]
        meta["error_description"] = error.localizedDescription
        
        var monitorProperties: [String: Any] = [:]
        monitorProperties["monitor_type"] = "metric"
        monitorProperties["monitor_name"] = "storekit2_fetch_transactions_error"
        monitorProperties["meta"] = meta
        
        let event = TikTokAppEvent.init(eventName: "MonitorEvent", withProperties: monitorProperties, withType: "monitor")
        TikTokBusiness.getInstance().report(event)
    }
}
