//
//  TTIAPTransactionEventRouter.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.
    
import StoreKit

@available(iOS 15.0, *)
final class TTIAPTransactionEventRouter {    
    let extraParams: [String: Any]
    
    let logger = TikTokLogger()
    
    init(extraParams: [String : Any]) {
        self.extraParams = extraParams
        logger.setLogLevel(TikTokLogLevelDebug)
    }
}
