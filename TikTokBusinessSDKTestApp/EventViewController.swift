//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
import TikTokBusinessSDK
import StoreKit

class EventViewController: UIViewController {
    
    var eventTextField =  UITextField()
    var finalPayloadTextView = UITextView()
    var numberOfEventsField = UITextField()
    let selectEventButton = UIButton(type: .system)
    let postEventButton = UIButton(type: .system)
    let postTTEventButton = UIButton(type: .system)
    let generateRandomEventsButton = UIButton(type: .system)
    let flushButton = UIButton(type: .system)
    let crashButton = UIButton(type: .system)
    
    let delegate = UIApplication.shared.delegate as! AppDelegate
    var eventPickerView = UIPickerView()
    
    let events = ["MonitorEvent","CustomEvent","AddToCart","AddToWishlist","Checkout","Purchase","ViewContent","AchieveLevel","AddPaymentInfo","CompleteTutorial","CreateGroup","CreateRole","GenerateLead","InAppADClick","InAppADImpr","InstallApp","JoinGroup","LaunchAPP","LoanApplication","LoanApproval","LoanDisbursal","Login","Rate","Registration","Search","SpendCredits","StartTrial","Subscribe","UnlockAchievement"]
    
    
    
    var eventToField =
        [
            "MonitorEvent": [],
            "CustomEvent": [],
            "AddToCart": ["content_type","content_id","description","currency","value"],
            "AddToWishlist": ["content_type","content_id","description","currency","value"],
            "Checkout": ["content_type","content_id","description","currency","value"],
            "Purchase": ["content_type","content_id","description","currency","value"],
            "ViewContent": ["content_type","content_id","description","currency","value"],
            "AchieveLevel": [],
            "AddPaymentInfo": [],
            "CompleteTutorial": [],
            "CreateGroup": [],
            "CreateRole": [],
            "GenerateLead": [],
            "InAppADClick": [],
            "InAppADImpr": [],
            "InstallApp": [],
            "JoinGroup": [],
            "LaunchAPP": [],
            "LoanApplication": [],
            "LoanApproval": [],
            "LoanDisbursal": [],
            "Login": [],
            "Rate": [],
            "Registration": [],
            "Search": [],
            "SpendCredits": [],
            "StartTrial": [],
            "Subscribe": [],
            "UnlockAchievement": []
    ]
    
    var titleForForm = "LaunchAPP"
    var payload = "{\n\n}"
    var eventTitle = ""
    var tiktok: Any?
    var eventToPost = TikTokBaseEvent()
    
    let productId = "com.TikTok.TikTokBusinessSDKTestApp.ConsumablePurchaseOne"
    
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
        eventTextField.frame = CGRect(x: 50, y: 100, width: 300, height: 40)
        eventTextField.borderStyle = .roundedRect
        view.addSubview(eventTextField)
        eventTextField.inputView = eventPickerView
        eventTextField.textAlignment = .center
        eventTextField.placeholder = "Select an event"
        
        selectEventButton.setTitle("Select Event", for: .normal)
        selectEventButton.frame = CGRect(x: 50, y: 150, width: 300, height: 40)
        selectEventButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        selectEventButton.layer.cornerRadius = 10
        selectEventButton.setTitleColor(.white, for: .normal)
        selectEventButton.addTarget(self, action: #selector(didSelectEvent), for: .touchUpInside)
        view.addSubview(selectEventButton)
        
        finalPayloadTextView.frame = CGRect(x: 50, y: 200, width: 300, height: 200)
        finalPayloadTextView.layer.borderWidth = 1
        finalPayloadTextView.layer.cornerRadius = 8
        finalPayloadTextView.layer.borderColor = UIColor.lightGray.cgColor
        finalPayloadTextView.isScrollEnabled = true
        finalPayloadTextView.textColor = .black
        view.addSubview(finalPayloadTextView)
        
        numberOfEventsField.frame = CGRect(x: 50, y: 410, width: 300, height: 40)
        numberOfEventsField.borderStyle = .roundedRect
        numberOfEventsField.textAlignment = .center
        numberOfEventsField.addTarget(self, action: #selector(numberOfEventsChanged), for: .editingChanged)
        numberOfEventsField.placeholder = "Enter number of events"
        view.addSubview(numberOfEventsField)
        
        generateRandomEventsButton.setTitle("Generate Random events", for: .normal)
        generateRandomEventsButton.frame = CGRect(x: 50, y: 460, width: 300, height: 40)
        generateRandomEventsButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        generateRandomEventsButton.setTitleColor(.white, for: .normal)
        generateRandomEventsButton.layer.cornerRadius = 10
        generateRandomEventsButton.addTarget(self, action: #selector(generateRandomEvents), for: .touchUpInside)
        view.addSubview(generateRandomEventsButton)
        
        postEventButton.setTitle("Post Event (trackEvent)", for: .normal)
        postEventButton.frame = CGRect(x: 50, y: 510, width: 300, height: 40)
        postEventButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        postEventButton.setTitleColor(.white, for: .normal)
        postEventButton.layer.cornerRadius = 10
        postEventButton.addTarget(self, action: #selector(eventPosted), for: .touchUpInside)
        view.addSubview(postEventButton)
        
        postTTEventButton.setTitle("Post Event (trackTTEvent)", for: .normal)
        postTTEventButton.frame = CGRect(x: 50, y: 560, width: 300, height: 40)
        postTTEventButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        postTTEventButton.setTitleColor(.white, for: .normal)
        postTTEventButton.layer.cornerRadius = 10
        postTTEventButton.addTarget(self, action: #selector(ttEventPosted), for: .touchUpInside)
        view.addSubview(postTTEventButton)
        
        flushButton.setTitle("flush", for: .normal)
        flushButton.frame = CGRect(x: 50, y: 610, width: 300, height: 40)
        flushButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        flushButton.setTitleColor(.white, for: .normal)
        flushButton.layer.cornerRadius = 10
        flushButton.addTarget(self, action: #selector(eventFlush), for: .touchUpInside)
        view.addSubview(flushButton)
        
        crashButton.setTitle("Crash App", for: .normal)
        crashButton.frame = CGRect(x: 50, y: 660, width: 300, height: 40)
        crashButton.backgroundColor = .red
        crashButton.setTitleColor(.white, for: .normal)
        crashButton.layer.cornerRadius = 10
        crashButton.addTarget(self, action: #selector(crashApp), for: .touchUpInside)
        view.addSubview(crashButton)
        
        if(eventTitle.count > 0){
            eventTextField.text = eventTitle
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if eventToPost.eventName.count != 0 {
            payload = "{\n"
            payload += "\t\"event\": \""
            payload += eventToPost.eventName
            payload += "\",\n"
            if !eventToPost.eventId.isEmpty {
                payload += "\t\"event_id"
                payload += "\": \""
                payload += eventToPost.eventId
                payload += "\",\n"
            }
            payload += "\t\"properties\": "
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: eventToPost.properties, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    let propertyString = jsonString.replacingOccurrences(of: ",", with: ",\n\t\t")
                        .replacingOccurrences(of: "{", with: "{\n\t\t")
                        .replacingOccurrences(of: "}", with: "\n\t\t}")
                    payload += propertyString
                    payload += "\n"
                }
            } catch {
                print("JSON convert error: \(error.localizedDescription)")
            }
            payload += "}"
        }
        finalPayloadTextView.text = payload
    }

    @objc func didSelectEvent(_ sender: Any) {
        
        self.titleForForm = eventTextField.text!
        if(eventTextField.text!.count > 0){
            let formVC = FormViewController()
            formVC.titleName = self.titleForForm
            formVC.parentVC = self
            navigationController?.pushViewController(formVC, animated: true)
        } else {
            print("Please select an event to continue")
        }
        
        
    }
    
    @objc func eventPosted(_ sender: Any) {
        let finalPayloadJSONString = finalPayloadTextView.text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
        let finalPayloadJSON = finalPayloadJSONString.data(using: .utf8)!
        
        let finalPayloadDictionary = try? JSONSerialization.jsonObject(with: finalPayloadJSON, options: JSONSerialization.ReadingOptions.mutableContainers) as? [AnyHashable : Any]
        
        if let eventName = finalPayloadDictionary?["event"] as? String, let properties = finalPayloadDictionary?["properties"] {
            print("Event " + eventName + " posted")
            finalPayloadTextView.text = "{\n\t\"response\": \"SUCCESS\"\n}"
            if(eventTitle != "MonitorEvent"){
                TikTokBusiness.trackEvent(eventName, withProperties: properties as! [AnyHashable : Any])
            } else {
                TikTokBusiness.trackEvent(eventTitle, withType: "monitor")
            }
        }
        
    }
    
    @objc func ttEventPosted(_ sender: Any) {
        let finalPayloadJSONString = finalPayloadTextView.text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
        let finalPayloadJSON = finalPayloadJSONString.data(using: .utf8)!
        
        let finalPayloadDictionary = try? JSONSerialization.jsonObject(with: finalPayloadJSON, options: JSONSerialization.ReadingOptions.mutableContainers) as? [AnyHashable : Any]
        
        if let eventName = finalPayloadDictionary?["event"] as? String, let properties = finalPayloadDictionary?["properties"] {
            print("Event " + eventName + " posted")
            finalPayloadTextView.text = "{\n\t\"response\": \"SUCCESS\"\n}"
            for (key, value) in properties as! [AnyHashable : Any] {
                eventToPost.addProperty(withKey: key as! String, value: value)
            }
            TikTokBusiness.trackTTEvent(eventToPost)
        }
    }
    
    @objc func numberOfEventsChanged(_ sender: Any) {
        if((numberOfEventsField.text?.count)! > 0){
            generateRandomEventsButton.setTitle("Generate \(numberOfEventsField.text ?? "") Random events", for: .normal)
        }
    }

    
    @objc func generateRandomEvents(_ sender: Any) {
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
            finalPayloadTextView.text = "{\n\t\"repsonse\": \"SUCCESS\"\n}"
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
    
    @objc func crashApp(_ sender: UIButton) {
        print("crash app was called!");
        TikTokBusiness.produceFatalError()
    }
    
    @objc func eventFlush(_ sender: UIButton) {
        print("flush was called!");
        TikTokBusiness.explicitlyFlush()
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
