//
//  TTSK1ProductFetcher.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/6/3.
//  Copyright © 2026 TikTok. All rights reserved.

import StoreKit

@available(iOS 15.0, *)
final class TTSK1ProductFetcher: NSObject, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var continuation: CheckedContinuation<SKProduct?, Never>?

    func product(for productID: String) async -> SKProduct? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let request = SKProductsRequest(productIdentifiers: [productID])
            request.delegate = self
            self.request = request
            request.start()
        }
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        finish(response.products.first)
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        finish(nil)
    }

    func requestDidFinish(_ request: SKRequest) {
        finish(nil)
    }

    private func finish(_ product: SKProduct?) {
        guard let continuation else {
            return
        }

        self.continuation = nil
        request?.delegate = nil
        request = nil

        continuation.resume(returning: product)
    }
}
