//
//  TTStoreKitObserver.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.
    

import Foundation
import StoreKit

#if TikTokBusinessSDK_SPM
import TikTokBusinessSDKCore
#endif

fileprivate let SKIncludeConsumableInAppPurchaseHistory = "SKIncludeConsumableInAppPurchaseHistory"

@available(iOS 15.0, *)
@objc(TikTokStoreKitObserver)
public final actor TTStoreKitObserver: NSObject {
    
    static let shared = TTStoreKitObserver()

    var pollingTask: Task<Void, Never>?
    var isObserving = false
    let pollInterval: UInt64
    private(set) var extraParams: [String: Any] = [:]
    private let logger = TikTokLogger()

    private override init() {
        if TikTokBusiness.getInstance().storeKit2ObserveInterval > 0 {
            self.pollInterval = TikTokBusiness.getInstance().storeKit2ObserveInterval
        } else {
            self.pollInterval = 600_000
        }
        super.init()
        if TikTokBusiness.getInstance().isStoreKit2ReportConsumableStateEnabled,
            let includeConsumableState = Bundle.main.object(forInfoDictionaryKey: SKIncludeConsumableInAppPurchaseHistory) as? Bool {
            extraParams["skIncludeConsumableInAppPurchaseHistory"] = includeConsumableState
        }
        logger.setLogLevel(TikTokLogLevelDebug)
    }

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        startObserveStoreKit2()
        startObserveStoreKit1()
    }

    func stopObserving() {
        stopObserveStoreKit2()
        stopObserveStoreKit1()
        isObserving = false
    }
    
    func debugMessage(_ message: String) {
        logger.debugMessage("[TTStoreKitObserver]" + message)
    }
}

@available(iOS 15.0, *)
extension TTStoreKitObserver {
    @objc static func start() {
        Task {
            await Self.shared.startObserving()
        }
    }
    
    @objc static func stop() {
        Task {
            await Self.shared.stopObserving()
        }
    }
}
