//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
import StoreKit

import UIKit

class PurchaseViewController: UIViewController, SKPaymentTransactionObserver {
    
    let consumableProductId = "com.tiktok.TikTokBusinessSDKTestApp.ConsumablePurchaseOne";
    let nonConsumableProductId = "com.tiktok.TikTokBusinessSDKTestApp.NonConsumablePurchaseOne";
    let ARSubscriptionProductId = "com.tiktok.TikTokBusinessSDKTestApp.ARSubscriptionPurchaseOne";
    let NRSubscriptionProductId = "com.tiktok.TikTokBusinessSDKTestApp.NRSubscriptionPurchaseOne";
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            if transaction.transactionState != .purchasing {
                queue.finishTransaction(transaction);
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        SKPaymentQueue.default().add(self)

        let buttonWidth: CGFloat = 300
        let buttonHeight: CGFloat = 60
        let buttonSpacing: CGFloat = 20
        let cornerRadius: CGFloat = 10
        let startY: CGFloat = (view.frame.height - 5 * buttonHeight - 4 * buttonSpacing) / 2
        let bgColor: UIColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        

        let consumable = UIButton(type: .system)
        consumable.frame = CGRect(x: (view.frame.width - buttonWidth) / 2, y: startY, width: buttonWidth, height: buttonHeight)
        consumable.setTitle("Consumable for $0.99", for: .normal)
        consumable.setTitleColor(.white, for: .normal)
        consumable.backgroundColor = bgColor
        consumable.layer.cornerRadius = cornerRadius
        consumable.addTarget(self, action: #selector(consumableTapped), for: .touchUpInside)
        view.addSubview(consumable)

        // 创建按钮2
        let nconsumable = UIButton(type: .system)
        nconsumable.frame = CGRect(x: (view.frame.width - buttonWidth) / 2, y: startY + buttonHeight + buttonSpacing, width: buttonWidth, height: buttonHeight)
        nconsumable.setTitle("Non-Consumable for $0.99", for: .normal)
        nconsumable.setTitleColor(.white, for: .normal)
        nconsumable.backgroundColor = bgColor
        nconsumable.layer.cornerRadius = cornerRadius
        nconsumable.addTarget(self, action: #selector(nconsumableTapped), for: .touchUpInside)
        view.addSubview(nconsumable)

        // 创建按钮3
        let arSubscription = UIButton(type: .system)
        arSubscription.frame = CGRect(x: (view.frame.width - buttonWidth) / 2, y: startY + 2 * (buttonHeight + buttonSpacing), width: buttonWidth, height: buttonHeight)
        arSubscription.setTitle("Auto-Renew. Subscription for $0.99", for: .normal)
        arSubscription.setTitleColor(.white, for: .normal)
        arSubscription.backgroundColor = bgColor
        arSubscription.layer.cornerRadius = cornerRadius
        arSubscription.addTarget(self, action: #selector(arSubscriptionTapped), for: .touchUpInside)
        view.addSubview(arSubscription)

        // 创建按钮4
        let nrSubscription = UIButton(type: .system)
        nrSubscription.frame = CGRect(x: (view.frame.width - buttonWidth) / 2, y: startY + 3 * (buttonHeight + buttonSpacing), width: buttonWidth, height: buttonHeight)
        nrSubscription.setTitle("Non-Renew. Subscription for $0.99", for: .normal)
        nrSubscription.setTitleColor(.white, for: .normal)
        nrSubscription.backgroundColor = bgColor
        nrSubscription.layer.cornerRadius = cornerRadius
        nrSubscription.addTarget(self, action: #selector(nrSubscriptionTapped), for: .touchUpInside)
        view.addSubview(nrSubscription)

        // 创建按钮5
        let restore = UIButton(type: .system)
        restore.frame = CGRect(x: (view.frame.width - buttonWidth) / 2, y: startY + 4 * (buttonHeight + buttonSpacing), width: buttonWidth, height: buttonHeight)
        restore.setTitle("Restore All Purchases", for: .normal)
        restore.setTitleColor(.white, for: .normal)
        restore.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        restore.backgroundColor = .green
        restore.layer.cornerRadius = cornerRadius
        restore.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        view.addSubview(restore)
    }

    @objc func consumableTapped() {
        print("Consumable Purchased!")
        
        if SKPaymentQueue.canMakePayments() {
            let paymentRequest = SKMutablePayment()
            paymentRequest.productIdentifier = consumableProductId
            SKPaymentQueue.default().add(paymentRequest)
        } else {
            print("User unable to make payments!")
        }
    }

    @objc func nconsumableTapped() {
        print("Non-Consumable Purchased!")
        
        if SKPaymentQueue.canMakePayments() {
            let paymentRequest = SKMutablePayment()
            paymentRequest.productIdentifier = nonConsumableProductId
            SKPaymentQueue.default().add(paymentRequest)
        } else {
            print("User unable to make payments!")
        }
    }

    @objc func arSubscriptionTapped() {
        print("Auto-Renewable Subscription Purchased!")
        
        if SKPaymentQueue.canMakePayments() {
            let paymentRequest = SKMutablePayment()
            paymentRequest.productIdentifier = ARSubscriptionProductId
            SKPaymentQueue.default().add(paymentRequest)
        } else {
            print("User unable to make payments!")
        }
    }

    @objc func nrSubscriptionTapped() {
        print("Non-Renewable Subscription Purchased!")
        
        if SKPaymentQueue.canMakePayments() {
            let paymentRequest = SKMutablePayment()
            paymentRequest.productIdentifier = NRSubscriptionProductId
            SKPaymentQueue.default().add(paymentRequest)
        } else {
            print("User unable to make payments!")
        }
    }

    @objc func restoreTapped() {
        print("Restored All Purchase!")
        if SKPaymentQueue.canMakePayments() {
            SKPaymentQueue.default().restoreCompletedTransactions();
        }
    }
}
