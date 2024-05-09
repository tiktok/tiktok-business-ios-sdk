//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
import TikTokBusinessSDK

class MetricsViewController: UIViewController {
    
    @IBOutlet weak var numberOfEventsField: UITextField!
    @IBOutlet weak var randomEvents: UIButton!
    @IBOutlet weak var numberOfEventsDumped: UILabel!
    @IBOutlet weak var numberOfEventsInMemory: UILabel!
    @IBOutlet weak var numberOfEventsInDisk: UILabel!
    @IBOutlet weak var secondsUntilFlush: UILabel!
    @IBOutlet weak var remainingNumberOfEventsUntilFlush: UILabel!
    
    let events = ["CustomEvent", "LaunchAPP", "InstallApp", "2Dretention", "AddPaymentInfo", "AddToCart", "AddToWishList", "Checkout", "CompleteTutorial", "ViewContent", "CreateGroup", "CreateRole", "GenerateLead", "InAppADClick", "InAppADImpr", "JoinGroup", "AchieveLevel", "LoanApplication", "LoanApproval", "LoanDisbursal", "Login", "Purchase", "Rate", "Registration", "Search", "SpendCredits", "StartTrial", "Subscribe", "Share", "Contact", "UnlockAchievement"]
    
    var eventToField =
        [
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
            "InAppADClick": ["ad_type"],
            "InAppADImpr": ["ad_type"],
            "JoinGroup": ["level_numer"],
            "AchieveLevel": ["level_number", "score"],
            "LoanApplication": ["loan_type", "application_id"],
            "LoanApproval": ["value"],
            "LoanDisbursal": ["value"],
            "Login": [],
            "Purchase": ["page_type", "value", "sku_id", "description", "number_of_items", "coupon_used", "currency", "group_type", "game_item_id", "room_type", "location", "checkin_date", "checkout_date", "number_of_rooms", "number_of_nights", "outbound_origination_city", "outbound_destination_city", "return_origination_city", "return_destination_city", "class", "number_of_passenger", "service_type", "service_id"],
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
    
    var payload = NSMutableDictionary()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Queue Metrics"
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        
        if((numberOfEventsField.text?.count)! > 0){
            randomEvents.setTitle("Generate " + "Random events", for: .normal)
        }

        numberOfEventsInMemory.text = String(TikTokBusiness.getInMemoryEventCount());
        numberOfEventsInDisk.text = String(TikTokBusiness.getInDiskEventCount());
        numberOfEventsDumped.text = String(0);
        secondsUntilFlush.text = String(TikTokBusiness.getTimeInSecondsUntilFlush())
        remainingNumberOfEventsUntilFlush.text = String(TikTokBusiness.getRemainingEventsUntilFlushThreshold())

        NotificationCenter.default.addObserver(self, selector: #selector(onInMemoryEventQueueUpdate(_:)), name: NSNotification.Name(rawValue: "inMemoryEventQueueUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onInDiskEventQueueUpdate(_:)), name: NSNotification.Name(rawValue: "inDiskEventQueueUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onEventsDumped(_:)), name: NSNotification.Name(rawValue: "eventsDumped"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onTimeLeft(_:)), name: NSNotification.Name(rawValue: "timeLeft"), object: nil)
    }
    
    @objc func onInMemoryEventQueueUpdate(_ notification:Notification) {
        numberOfEventsInMemory.text = String(TikTokBusiness.getInMemoryEventCount());
        remainingNumberOfEventsUntilFlush.text = String(TikTokBusiness.getRemainingEventsUntilFlushThreshold());
    }
    
    @objc func onInDiskEventQueueUpdate(_ notification:Notification) {
        numberOfEventsInDisk.text = String(TikTokBusiness.getInDiskEventCount());
    }
    
    @objc func onTimeLeft(_ notification:Notification) {
        secondsUntilFlush.text = String(TikTokBusiness.getTimeInSecondsUntilFlush());
    }
    
    @objc func onEventsDumped(_ notification:Notification) {
        if let userInfo = notification.userInfo as [AnyHashable : Any]? {
          if let eventsDumped = userInfo["numberOfEventsDumped"] as? Int {
            numberOfEventsDumped.text = String(eventsDumped)
          }
        }
    }
    
    @IBAction func numberOfEventsChanged(_ sender: Any) {
        if((numberOfEventsField.text?.count)! > 0){
            randomEvents.setTitle("Generate \(numberOfEventsField.text ?? "") Random events", for: .normal)
        }
    }
    
    @IBAction func generateRandomEvents(_ sender: Any) {
        let count = Int(numberOfEventsField.text ?? "") ?? 0
        if(numberOfEventsField.text!.count <= 0 || numberOfEventsField.text == "0") {return}
        for var num in 0...count - 1 {
            let randomEvent = self.events.randomElement();
            if(randomEvent == "LaunchAPP" || randomEvent == "InstallApp") {
                num -= 1
            }
            self.payload.setValue(randomEvent, forKey: "event_name")
            let fields = eventToField[randomEvent!]
            for fieldIndex in 0 ..< fields!.count {
                self.payload.setValue(randomText(from: 5, to: 20), forKey: fields![fieldIndex])
            }
            TikTokBusiness.trackEvent(randomEvent!, withProperties: self.payload as! [AnyHashable : Any])
        }
    }
    
    @IBAction func identify(_ sender: UIButton) {
        // enter identify values here
        TikTokBusiness.identify(withExternalID: "123", phoneNumber: nil, email: "test@tiktok.com")
    }
    
    @IBAction func logout(_ sender: UIButton) {
        TikTokBusiness.logout();
    }
    
    @IBAction func flush(_ sender: UIButton) {
        TikTokBusiness.explicitlyFlush();
    }
    
    @IBAction func crashhApp(_ sender: UIButton) {
        print("crash app was called!");
        TikTokBusiness.produceFatalError()
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

}
