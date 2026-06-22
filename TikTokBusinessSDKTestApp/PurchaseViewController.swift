//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
import StoreKit
import TikTokBusinessSDK

class PurchaseViewController: UIViewController, SKPaymentTransactionObserver {

    // MARK: - StoreKit 模式

    enum StoreKitMode {
        case storeKit1
        case storeKit2
        case both
    }

    private var mode: StoreKitMode = .storeKit1

    // 三个选项：SK1 / SK2 / Both
    private lazy var modeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["StoreKit1", "StoreKit2", "Both"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        if #available(iOS 13.0, *) {
            control.selectedSegmentTintColor = .orange
        } else {
            // Fallback on earlier versions
        }
        return control
    }()

    // MARK: - Product IDs

    let consumableProductId    = "com.tiktok.TikTokBusinessSDKTestApp.ConsumablePurchaseOne"
    let nonConsumableProductId = "com.tiktok.TikTokBusinessSDKTestApp.NonConsumablePurchaseOne"
    let ARSubscriptionProductId = "com.tiktok.TikTokBusinessSDKTestApp.ARSubscriptionPurchaseOne"
    let NRSubscriptionProductId = "com.tiktok.TikTokBusinessSDKTestApp.NRSubscriptionPurchaseOne"

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            // demo 中：非 .purchasing 状态一律 finish
            if transaction.transactionState != .purchasing {
                queue.finishTransaction(transaction)
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // StoreKit1 观察者（用于 finish SK1 交易）
        SKPaymentQueue.default().add(self)

        setupUI()
    }

    // MARK: - UI 布局

    private func setupUI() {
        let buttonWidth: CGFloat = 300
        let buttonHeight: CGFloat = 60
        let buttonSpacing: CGFloat = 20
        let cornerRadius: CGFloat = 10

        // 先布局 segmented control
        let topSafe = view.safeAreaInsets.top
        modeControl.frame = CGRect(x: 20,
                                   y: topSafe + 120,
                                   width: view.frame.width - 40,
                                   height: 32)
        view.addSubview(modeControl)

        let bgColor: UIColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)

        // 下面 5 个按钮沿用原有布局，只是起始 Y 往下挪一块高度给 segmented control
        let startY: CGFloat = modeControl.frame.maxY + 40

        // 1. Consumable
        let consumable = UIButton(type: .system)
        consumable.frame = CGRect(x: (view.frame.width - buttonWidth) / 2,
                                  y: startY,
                                  width: buttonWidth,
                                  height: buttonHeight)
        consumable.setTitle("Consumable for $0.99", for: .normal)
        consumable.setTitleColor(.white, for: .normal)
        consumable.backgroundColor = bgColor
        consumable.layer.cornerRadius = cornerRadius
        consumable.addTarget(self, action: #selector(consumableTapped), for: .touchUpInside)
        view.addSubview(consumable)

        // 2. Non-Consumable
        let nconsumable = UIButton(type: .system)
        nconsumable.frame = CGRect(x: (view.frame.width - buttonWidth) / 2,
                                   y: startY + buttonHeight + buttonSpacing,
                                   width: buttonWidth,
                                   height: buttonHeight)
        nconsumable.setTitle("Non-Consumable for $0.99", for: .normal)
        nconsumable.setTitleColor(.white, for: .normal)
        nconsumable.backgroundColor = bgColor
        nconsumable.layer.cornerRadius = cornerRadius
        nconsumable.addTarget(self, action: #selector(nconsumableTapped), for: .touchUpInside)
        view.addSubview(nconsumable)

        // 3. Auto-Renew Subscription
        let arSubscription = UIButton(type: .system)
        arSubscription.frame = CGRect(x: (view.frame.width - buttonWidth) / 2,
                                      y: startY + 2 * (buttonHeight + buttonSpacing),
                                      width: buttonWidth,
                                      height: buttonHeight)
        arSubscription.setTitle("Auto-Renew. Subscription for $0.99", for: .normal)
        arSubscription.setTitleColor(.white, for: .normal)
        arSubscription.backgroundColor = bgColor
        arSubscription.layer.cornerRadius = cornerRadius
        arSubscription.addTarget(self, action: #selector(arSubscriptionTapped), for: .touchUpInside)
        view.addSubview(arSubscription)

        // 4. Non-Renew Subscription
        let nrSubscription = UIButton(type: .system)
        nrSubscription.frame = CGRect(x: (view.frame.width - buttonWidth) / 2,
                                      y: startY + 3 * (buttonHeight + buttonSpacing),
                                      width: buttonWidth,
                                      height: buttonHeight)
        nrSubscription.setTitle("Non-Renew. Subscription for $0.99", for: .normal)
        nrSubscription.setTitleColor(.white, for: .normal)
        nrSubscription.backgroundColor = bgColor
        nrSubscription.layer.cornerRadius = cornerRadius
        nrSubscription.addTarget(self, action: #selector(nrSubscriptionTapped), for: .touchUpInside)
        view.addSubview(nrSubscription)

        // 5. Restore purchases
        let restore = UIButton(type: .system)
        restore.frame = CGRect(x: (view.frame.width - buttonWidth) / 2,
                               y: startY + 4 * (buttonHeight + buttonSpacing),
                               width: buttonWidth,
                               height: buttonHeight)
        restore.setTitle("Restore All Purchases", for: .normal)
        restore.setTitleColor(.white, for: .normal)
        restore.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        restore.backgroundColor = .green
        restore.layer.cornerRadius = cornerRadius
        restore.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        view.addSubview(restore)
    }

    // MARK: - 模式切换

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            mode = .storeKit1
        case 1:
            mode = .storeKit2
        case 2:
            mode = .both
        default:
            mode = .storeKit1
        }
        print("StoreKit mode =", mode)
    }

    // MARK: - Button Actions

    @objc func consumableTapped() {
        print("Consumable button tapped")
        startPurchase(productId: consumableProductId)
    }

    @objc func nconsumableTapped() {
        print("Non-Consumable button tapped")
        startPurchase(productId: nonConsumableProductId)
    }

    @objc func arSubscriptionTapped() {
        print("Auto-Renew Subscription button tapped")
        startPurchase(productId: ARSubscriptionProductId)
    }

    @objc func nrSubscriptionTapped() {
        print("Non-Renew Subscription button tapped")
        startPurchase(productId: NRSubscriptionProductId)
    }

    @objc func restoreTapped() {
        print("Restore button tapped")
        switch mode {
        case .storeKit1:
            SKPaymentQueue.default().restoreCompletedTransactions()

        case .storeKit2:
            if #available(iOS 15.0, *) {
                Task {
                    await restoreWithStoreKit2()
                }
            } else {
                // 老系统没有 SK2，退回 SK1
                SKPaymentQueue.default().restoreCompletedTransactions()
            }

        case .both:
            // 两种都试一遍，方便联调
            SKPaymentQueue.default().restoreCompletedTransactions()
            if #available(iOS 15.0, *) {
                Task {
                    await restoreWithStoreKit2()
                }
            }
        }
    }

    // MARK: - 统一入口，根据模式选择 SK1 / SK2 / Both

    private func startPurchase(productId: String) {
        switch mode {
        case .storeKit1:
            purchaseWithStoreKit1(productId: productId)

        case .storeKit2:
            if #available(iOS 15.0, *) {
                Task {
                    await purchaseWithStoreKit2(productId: productId)
                }
            } else {
                // 老系统没有 StoreKit2，fallback 到 StoreKit1
                purchaseWithStoreKit1(productId: productId)
            }

        case .both:
            // 同时触发 SK1 + SK2，主要用于测试/对比
            purchaseWithStoreKit1(productId: productId)
            if #available(iOS 15.0, *) {
                Task {
                    await purchaseWithStoreKit2(productId: productId)
                }
            }
        }
    }

    // MARK: - StoreKit1 实现

    private func purchaseWithStoreKit1(productId: String) {
        guard SKPaymentQueue.canMakePayments() else {
            print("In-app purchases are disabled (StoreKit1)")
            return
        }
        let paymentRequest = SKMutablePayment()
        paymentRequest.productIdentifier = productId
        SKPaymentQueue.default().add(paymentRequest)
    }

    // MARK: - StoreKit2 实现

    @available(iOS 15.0, *)
    private func purchaseWithStoreKit2(productId: String) async {
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
                print("[SK2] No product found for id: \(productId)")
                return
            }

            print("[SK2] Purchasing product: \(product.id)")
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("[SK2] Purchase success for \(transaction.productID)")
                    // 对于 StoreKit2，推荐使用 finish() 完成交易
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    print("[SK2] Unverified transaction \(transaction.productID), error: \(String(describing: error))")
                }

            case .pending:
                print("[SK2] Purchase pending")

            case .userCancelled:
                TikTokBusiness.getInstance().trackStoreKit2PurchaseFailed(productId: product.id)
                print("[SK2] User cancelled")

            @unknown default:
                TikTokBusiness.getInstance().trackStoreKit2PurchaseFailed(productId: product.id)
                print("[SK2] Unknown purchase result")
            }
        } catch {
            print("[SK2] purchase error: \(error)")
        }
    }

    @available(iOS 15.0, *)
    private func restoreWithStoreKit2() async {
        do {
            print("[SK2] Restoring current entitlements...")
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    print("[SK2] Restored entitlement for product: \(transaction.productID)")
                    // demo 里直接 finish；实际业务可根据需要是否调用
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    print("[SK2] Unverified entitlement \(transaction.productID), error: \(String(describing: error))")
                }
            }
        } catch {
            print("[SK2] restore error: \(error)")
        }
    }
}
