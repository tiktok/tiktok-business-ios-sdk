//
//  TTStoreKitObserver+Public.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.
    
// MARK: Public API
@available(iOS 15.0, *)
public extension TTStoreKitObserver {
    
}

@available(iOS 15.0, *)
public extension TikTokBusiness {
    @objc func trackStoreKit2PurchaseFailed(productId: String) {
        Task.detached {
            await TTStoreKitObserver.shared.handleFailed(productId)
        }
    }
}
