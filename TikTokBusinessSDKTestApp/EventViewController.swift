//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
import TikTokBusinessSDK
import StoreKit

class EventViewController: UIViewController, SKPaymentTransactionObserver {
    
    @IBOutlet weak var eventTextField: UITextField!
    @IBOutlet weak var finalPayloadTextField: UITextView!
    @IBOutlet weak var numberOfEventsField: UITextField!
    @IBOutlet weak var randomEvents: UIButton!
    
    let delegate = UIApplication.shared.delegate as! AppDelegate
    var eventPickerView = UIPickerView()
    
    let events = ["MonitorEvent", "CustomEvent", "LaunchAPP", "InstallApp", "2Dretention", "AddPaymentInfo", "AddToCart", "AddToWishList", "Checkout", "CompleteTutorial", "ViewContent", "CreateGroup", "CreateRole", "GenerateLead", "InAppAdClick", "InAppAdImpr", "JoinGroup", "AchieveLevel", "LoanApplication", "LoanApproval", "LoanDisbursal", "Login", "Purchase", "Rate", "Registration", "Search", "SpendCredits", "StartTrial", "Subscribe", "Share", "Contact", "UnlockAchievement"]
    
    var eventToField =
        [
            "MonitorEvent": [],
            "CustomEvent": [],
            "LaunchAPP": [],
            "InstallApp": [],
            "2Dretention": [],
            "AddPaymentInfo": ["app_id", "idfa", "attribution"],
            "AddToCart": ["content_type", "sku_id", "description", "currency", "value"],
            "AddToWishList": ["page_type", "content_id", "description", "currency", "value"],
            "Checkout": ["description", "sku_id", "number_of_items", "payment_unavailable", "currency", "value", "game_item_type", "game_item_id", "room_type", "currency", "value", "location", "checkin_date", "checkout_date", "number_of_rooms", "number_of_nights"],
            "CompleteTutorial": [],
            "ViewContent": ["page_type", "sku_id", "description", "currency", "value", "Search_string", "room_type", "location", "checkin_date", "checkout_date", "number_of_rooms", "number_of_nights", "outbound_origination_city", "outbound_destination_city", "return_origination_city", "return_destination_city", "class", "number_of_passenger"],
            "CreateGroup": ["group_name", "group_logo", "group_description", "group_type", "group_id"],
            "CreateRole": ["role_type"],
            "GenerateLead": [],
            "InAppAdClick": ["ad_type"],
            "InAppAdImpr": ["ad_type"],
            "JoinGroup": ["level_numer"],
            "AchieveLevel": ["level_number", "score"],
            "LoanApplication": ["loan_type", "application_id"],
            "LoanApproval": ["value"],
            "LoanDisbursal": ["value"],
            "Login": [],
            "Purchase": ["page_type", "sku_id", "description", "number_of_items", "coupon_used", "currency", "value", "group_type", "game_item_id", "room_type", "location", "checkin_date", "checkout_date", "number_of_rooms", "number_of_nights", "outbound_origination_city", "outbound_destination_city", "return_origination_city", "return_destination_city", "class", "number_of_passenger", "service_type", "service_id"],
            "Rate": ["page_type", "sku_id", "content", "rating_value", "max_rating_value", "rate"],
            "Registration": ["registration_method"],
            "Search": ["search_string", "checkin_date", "checkout_date", "number_of_rooms", "number_of_nights", "origination_city", "destination_city", "departure_date", "return_date", "class", "number_of_passenger"],
            "SpendCredits": ["game_item_type", "game_item_id", "level_number"],
            "StartTrial": ["order_id", "currency"],
            "Subscribe": ["order_id", "currency"],
            "Share": ["content_type", "content_id", "share_destination"],
            "Contact": [],
            "UnlockAchievement": ["description", "achievement_type"]
    ]
    
    var titleForForm = "LaunchAPP"
    var payload = "{\n\n}"
    var eventTitle = ""
    var tiktok: Any?
    
    let productId = "btd.TikTokBusinessSDKTestApp.ConsumableExampleThree"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initializing TikTok SDK
//        tiktok = delegate.;
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        title = "Event"
        eventPickerView.dataSource = self
        eventPickerView.delegate = self
        eventTextField.inputView = eventPickerView
        eventTextField.textAlignment = .center
        eventTextField.placeholder = "Select an event"
        finalPayloadTextField.text = payload
        
        if((numberOfEventsField.text?.count)! > 0){
            randomEvents.setTitle("Generate " + "Random events", for: .normal)
        }
        
//        randomEvents.setTitle("Generate random events", for: .normal)
        if(eventTitle.count > 0){
            eventTextField.text = eventTitle
        }
        
        SKPaymentQueue.default().add(self)
        // Do any additional setup after loading the view.
    }

    @IBAction func didSelectEvent(_ sender: Any) {
        
        self.titleForForm = eventTextField.text!
        if(eventTextField.text!.count > 0){
            performSegue(withIdentifier: "segueToForm", sender: self)
        } else {
            print("Please select an event to continue")
        }
        
        
    }

    @IBAction func numberOfEventsChanged(_ sender: Any) {
        if((numberOfEventsField.text?.count)! > 0){
            randomEvents.setTitle("Generate \(numberOfEventsField.text ?? "") Random events", for: .normal)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "segueToForm") {
            let vc = segue.destination as! FormViewController
            vc.titleName = self.titleForForm
        } else if (segue.identifier == "segueToMetrics") {
            _ = segue.destination as! MetricsViewController
//            vc.titleName = "Metrics Dashboard"
        } else if(segue.identifier == "segueToPurchase") {
            _ = segue.destination as! PurchaseViewController
        }
    }
    
    @IBAction func metricsButtonClicked(_ sender: Any) {
        performSegue(withIdentifier: "segueToMetrics", sender: self)
    }
    
    @IBAction func eventPosted(_ sender: Any) {
        // Ideally, user should not even have exposure to TikTokAppEvent class
        let finalPayloadJSON = finalPayloadTextField.text.data(using: .utf8)!
        let finalPayloadDictionary = try? JSONSerialization.jsonObject(with: finalPayloadJSON, options: [])
        print("Event " + eventTitle + " posted")
        finalPayloadTextField.text = "{\n\t\"response\": \"SUCCESS\"\n}"
        /* UNCOMMENT THIS LINE */
        if(eventTitle != "MonitorEvent"){
            TikTokBusiness.trackEvent(eventTitle, withProperties: finalPayloadDictionary as! [AnyHashable : Any])
        } else {
            TikTokBusiness.trackEvent(eventTitle, withType: "monitor")
        }
//        TikTokBusiness.logSKANConfig();
        /* Print statements used for debugging */
//        print("Hello");
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").appId)
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").appName)
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").appNamespace)
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").appVersion)
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").appBuild)
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").devicePlatform);
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").deviceIdForAdvertisers);
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").deviceVendorId);
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").localeInfo);
//        print(TikTokDeviceInfo.init(sdkPrefix: "1.1").userAgent);
//        print(TikTokDeviceInfo.init(sdkPrefix: "").ipInfo);
        
    }
    
    @IBAction func purchaseItem(_ sender: Any) {
        print("Purchased item!")
        
        if SKPaymentQueue.canMakePayments() {
            let paymentRequest = SKMutablePayment()
            paymentRequest.productIdentifier = productId
            SKPaymentQueue.default().add(paymentRequest)
        } else {
            print("User unable to make payments!")
        }
        
    }
    
    
    @IBAction func generateRandomEvents(_ sender: Any) {
        let count = Int(numberOfEventsField.text ?? "") ?? 0
        if(numberOfEventsField.text!.count <= 0) {return}
        for var num in 0...count - 1 {
            self.payload = ""
            let randomEvent = self.events.randomElement();
            if(randomEvent == "LaunchAPP" || randomEvent == "InstallApp") {
                num -= 1
            }
            self.payload = "{\n"
            self.payload += "\t\"event_name\": \""
            self.payload += randomEvent!
            self.payload += "\",\n"
            let fields = eventToField[randomEvent!]
            for fieldIndex in 0 ..< fields!.count {
                self.payload += "\t\""
                self.payload += fields![fieldIndex]
                self.payload += "\": \""
                self.payload += randomText(from: 5, to: 20)
                self.payload += "\",\n"
            }
            self.payload = self.payload + "}"
            let payloadJSON = self.payload.data(using: .utf8)!
            let payloadDictionary = try? JSONSerialization.jsonObject(with: payloadJSON, options: [])
            
            /* UNCOMMENT THIS LINE */
            TikTokBusiness.trackEvent(randomEvent!, withProperties: payloadDictionary as! [AnyHashable : Any])
        }
        finalPayloadTextField.text = "{\n\t\"repsonse\": \"SUCCESS\"\n}"
//        finalPayloadTextField.text = "{\n\t\"repsonse\": \"SUCCESSFULLY TRACKED \(numberOfEventsField.text) EVENTS TO TRACK!\"\n}"
    }
    
    func randomText(from: Int, to: Int, justLowerCase: Bool = false) -> String {
        var text = ""
        let range = UInt32(to - from)
        let length = Int(arc4random_uniform(range + 1)) + from
        for _ in 1...length {
            var decValue = 0  // ascii decimal value of a character
            var charType = 3  // default is lowercase
            if justLowerCase == false {
                // randomize the character type
                charType =  Int(arc4random_uniform(4))
            }
            switch charType {
            case 1:  // digit: random Int between 48 and 57
                decValue = Int(arc4random_uniform(10)) + 48
            case 2:  // uppercase letter
                decValue = Int(arc4random_uniform(26)) + 65
            case 3:  // lowercase letter
                decValue = Int(arc4random_uniform(26)) + 97
            default:  // space character
                decValue = 32
            }
            // get ASCII character from random decimal value
            let char = String(UnicodeScalar(decValue)!)
            text = text + char
            // remove double spaces
            text = text.replacingOccurrences(of: " ", with: "")
        }
        return text
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            if transaction.transactionState == .purchased {
                queue.finishTransaction(transaction);
            } else if transaction.transactionState == .failed {
                queue.finishTransaction(transaction);
            }
        }
    }

}

extension EventViewController: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return events.count
    }
    
}

extension EventViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return events[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        eventTextField.text = events[row]
        eventTextField.resignFirstResponder()
        eventTitle = eventTextField.text!
    }
    
}
