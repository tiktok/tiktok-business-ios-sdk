//
//  TikTokIAPTransactionTests.swift
//  TikTokBusinessSDKTests
//
//  Created by Guanghui Liang on 2026/6/8.
//  Copyright © 2026 TikTok. All rights reserved.

import XCTest
import StoreKit

@testable import TikTokBusinessSDK

let consumableProductId    = "com.tiktok.TikTokBusinessSDKTestApp.ConsumablePurchaseOne"
let nonConsumableProductId = "com.tiktok.TikTokBusinessSDKTestApp.NonConsumablePurchaseOne"
let ARSubscriptionProductId = "com.tiktok.TikTokBusinessSDKTestApp.ARSubscriptionPurchaseOne"
let NRSubscriptionProductId = "com.tiktok.TikTokBusinessSDKTestApp.NRSubscriptionPurchaseOne"

@available(iOS 15.0, *)
final class TikTokIAPTransactionTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTransactionCollect() async throws {
        let originalCount = try await Transaction.all.collect().count
        
        try await purchaseProduct(consumableProductId)
        
        let count = try await Transaction.all.collect().count
        XCTAssertEqual(originalCount + 1, count)
    }
    
    func testSK2Events() async throws {
        let exception = XCTestExpectation()
        TikTokBusiness.getInstance().isRemoteSwitchOn = true
        TikTokBusiness.getInstance().eventLogger = TikTokEventLogger.init(config: .init(accessToken: "tiktok", appId: "123456", tiktokAppId: "7890"))
        let persistence = TikTokAppEventPersistence();
        let originalEventsCount = persistence.eventsCount()
        
        try await purchaseProduct(consumableProductId)
        await TTStoreKitObserver.shared.startObserving()
        Task.detached {
            try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            exception.fulfill()
        }
        await fulfillment(of: [exception], timeout: 10)
        let eventsCount = persistence.eventsCount()
        XCTAssertEqual(originalEventsCount + 1, eventsCount)
    }
    
    func testSK2PurchaseFailed() async throws {
        let exception = XCTestExpectation()
        TikTokBusiness.getInstance().isRemoteSwitchOn = true
        TikTokBusiness.getInstance().eventLogger = TikTokEventLogger.init(config: .init(accessToken: "tiktok", appId: "123456", tiktokAppId: "7890"))
        await TTStoreKitObserver.shared.startObserving()
        let persistence = TikTokAppEventPersistence();
        let originalEventsCount = persistence.eventsCount()
        
        TikTokBusiness.getInstance().trackStoreKit2PurchaseFailed(productId: consumableProductId)
        Task.detached {
            try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            exception.fulfill()
        }
        await fulfillment(of: [exception], timeout: 10)
        let eventsCount = persistence.eventsCount()
        XCTAssertEqual(originalEventsCount + 1, eventsCount)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func purchaseProduct(_ product: String) async throws {
        let products = try await Product.products(for: [product])
        guard let product = products.first else {
            return
        }

        let result = try await product.purchase()

        if case .success(let verification) = result, case .verified(let transaction) = verification {
            await transaction.finish()
        }
    }

}
