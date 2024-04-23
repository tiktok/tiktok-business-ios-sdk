//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit

class FormViewController: UIViewController {
    
    var titleName = "Enter the fields"
    
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
    
    var payload = ""
    var fields = [UITextField]()
    var parameters = [UITextField]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = titleName
        
        let fieldsNames = eventToField[titleName]
        
        let createPayload = UIButton(frame: CGRect(x: 10.0, y:100.0, width: UIScreen.main.bounds.size.width - 80.0, height: 50.0))
        let addField = UIButton(frame: CGRect(x: UIScreen.main.bounds.size.width - 60.0, y:100.0, width: 50.0, height: 50.0))
        createPayload.backgroundColor = .blue
        addField.backgroundColor = .purple
        createPayload.setTitle("Create Payload", for: .normal)
        addField.setTitle("+", for: .normal)
        createPayload.addTarget(self, action: #selector(self.didCreatePayload(sender:)), for: .touchUpInside)
        addField.addTarget(self, action: #selector(self.addFieldToEvent(sender:)), for: .touchUpInside)

        self.view.addSubview(createPayload)
        self.view.addSubview(addField)
        for fieldIndex in 0 ..< fieldsNames!.count {
            let field = UITextField(frame: CGRect(x: 10.0, y:(100.0 + CGFloat((fieldIndex + 1) * 60)), width: UIScreen.main.bounds.size.width/2 - 15.0, height: 50.0))
            field.text = fieldsNames?[fieldIndex]
            field.backgroundColor = .yellow
            field.tag = fieldIndex
            field.autocorrectionType = .no
            let parameter = UITextField(frame: CGRect(x:UIScreen.main.bounds.size.width/2 + 5.0, y:(100.0 + CGFloat((fieldIndex + 1) * 60)), width: UIScreen.main.bounds.size.width/2 - 15.0, height: 50.0))
            parameter.text = randomText(from: 5, to: 20)
            parameter.backgroundColor = .red
            parameter.tag = fieldIndex
            parameter.autocorrectionType = .no
            self.fields.append(field)
            self.parameters.append(parameter)
            self.view.addSubview(field)
            self.view.addSubview(parameter)
        }
    }
    
    
    @IBAction func didCreatePayload(sender: UIButton) {

        self.payload = "{\n"
        self.payload += "\t\"event_name\": \""
        self.payload += self.titleName
        self.payload += "\",\n"
        
        
        for fieldIndex in 0 ..< fields.count {
            self.payload += "\t\""
            if let field = self.fieldsForTag(tag: fieldIndex){
                self.payload += field.text!
                self.payload += "\": \""
            }
            
            if let parameter = self.parametersForTag(tag: fieldIndex){
                self.payload += parameter.text!
                self.payload += "\",\n"
            }
        }
        self.payload = self.payload + "}"
        performSegue(withIdentifier: "segueToEvent", sender: self)
        
    }
    
    @IBAction func addFieldToEvent(sender: UIButton) {
        
        let field = UITextField(frame: CGRect(x: 10.0, y:(100.0 + CGFloat((self.fields.count + 1) * 60)), width: UIScreen.main.bounds.size.width/2 - 15.0, height: 50.0))
        field.backgroundColor = .yellow
        field.tag = self.fields.count
        field.autocorrectionType = .no
        let parameter = UITextField(frame: CGRect(x:UIScreen.main.bounds.size.width/2 + 5.0, y:(100.0 + CGFloat((self.fields.count + 1) * 60)), width: UIScreen.main.bounds.size.width/2 - 15.0, height: 50.0))
        parameter.text = randomText(from: 5, to: 20)
        parameter.backgroundColor = .red
        parameter.tag = self.fields.count
        parameter.autocorrectionType = .no
        self.fields.append(field)
        self.parameters.append(parameter)
        self.view.addSubview(field)
        self.view.addSubview(parameter)
    }
    
    func fieldsForTag( tag: Int ) -> UITextField? {
        return self.fields.filter({ $0.tag == tag }).first
    }
    
    func parametersForTag( tag: Int ) -> UITextField? {
        return self.parameters.filter({ $0.tag == tag }).first
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! EventViewController
        vc.payload = self.payload
        vc.eventTitle = self.titleName
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
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
