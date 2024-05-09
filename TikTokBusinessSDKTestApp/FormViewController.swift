//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
import TikTokBusinessSDK
import SwiftUI

class FormViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    var titleName = "Enter the fields"
    var parentVC: EventViewController?
    
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
    
    var contentsEventNames = ["AddToCart", "AddToWishlist", "Checkout", "Purchase", "ViewContent"]
    var contentFields = ["price", "quantity", "content_id", "content_category", "content_name", "brand"]
    var contentParameters = [UITextField]()
    
    var fields = [UITextField]()
    var parameters = [UITextField]()
    var event : TikTokBaseEvent = TikTokBaseEvent()
    var tableView = UITableView()
    var contentTableView = UITableView()
    var hasContent = false
    var contentLabel = UILabel()
    var createPayload = UIButton(type: .system)
    var addContent = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        title = titleName
        if contentsEventNames.contains(titleName) {
            if titleName == "AddToCart" {
                event = TikTokAddToCartEvent()
            } else if titleName == "AddToWishlist" {
                event = TikTokAddToWishlistEvent()
            } else if titleName == "Checkout" {
                event = TikTokCheckoutEvent()
            } else if titleName == "Purchase" {
                event = TikTokPurchaseEvent()
            } else if titleName == "ViewContent" {
                event = TikTokViewContentEvent()
            } else {
                event = TikTokContentsEvent(name: titleName)
            }
            hasContent = true
        } else {
            event = TikTokBaseEvent(eventname: titleName)
            hasContent = false
        }
        let fieldsNames = eventToField[titleName]
        
        createPayload.frame = CGRect(x: 10.0, y:100.0, width: UIScreen.main.bounds.size.width / 2 - 45.0, height: 50.0)
        createPayload.backgroundColor = .blue
        createPayload.setTitleColor(.white, for: .normal)
        createPayload.setTitle("Create Event", for: .normal)
        createPayload.layer.cornerRadius = 10
        createPayload.addTarget(self, action: #selector(self.didCreatePayload(sender:)), for: .touchUpInside)
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFieldToEvent(sender:)))
        navigationItem.rightBarButtonItem = addButton
        
        addContent.frame = CGRect(x: UIScreen.main.bounds.size.width / 2 - 25.0, y:100.0, width: UIScreen.main.bounds.size.width / 2 - 45.0, height: 50.0)
        addContent.backgroundColor = .blue
        addContent.setTitle("Add Contents", for: .normal)
        addContent.setTitleColor(.white, for: .normal)
        addContent.layer.cornerRadius = 10
        addContent.addTarget(self, action: #selector(self.didAddContents(sender:)), for: .touchUpInside)

        self.view.addSubview(createPayload)
        self.view.addSubview(addContent)
        
        tableView = UITableView(frame: CGRect(x: 10, y:160.0, width: UIScreen.main.bounds.size.width - 20, height:260.0), style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.borderWidth = 1
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.view.addSubview(tableView)
        
        contentLabel = UILabel(frame: CGRect(x: 10, y: 450, width: 100, height: 40))
        contentLabel.text = "Contents:"
        contentLabel.isHidden = true
        self.view.addSubview(contentLabel)
        
        contentTableView = UITableView(frame: CGRect(x: 10, y:480.0, width: UIScreen.main.bounds.size.width - 20, height:240.0), style: .plain)
        contentTableView.dataSource = self
        contentTableView.delegate = self
        contentTableView.layer.borderWidth = 1
        contentTableView.register(UITableViewCell.self, forCellReuseIdentifier: "contentCell")
        contentTableView.isHidden = true
        self.view.addSubview(contentTableView)
        
        
        for fieldIndex in 0 ..< fieldsNames!.count {
            let field = UITextField(frame: CGRect(x: 10, y: 5, width: 140, height: 30))
            field.text = fieldsNames?[fieldIndex]
//            field.backgroundColor = .yellow
            field.borderStyle = .roundedRect
            field.tag = fieldIndex
            field.autocorrectionType = .no
            field.delegate = self
            let parameter = UITextField(frame: CGRect(x: 160, y: 5, width: 200, height: 30))
            parameter.text = randomText(from: 5, to: 20)
            parameter.borderStyle = .roundedRect
            parameter.tag = fieldIndex
            parameter.autocorrectionType = .no
            parameter.delegate = self
            self.fields.append(field)
            self.parameters.append(parameter)
        }
        
        for fieldIndex in 0 ..< contentFields.count {
            let parameter = UITextField(frame: CGRect(x: 160, y: 5, width: 200, height: 30))
            parameter.borderStyle = .roundedRect
            parameter.tag = fieldIndex
            parameter.autocorrectionType = .no
            parameter.delegate = self
            self.contentParameters.append(parameter)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tableView == self.tableView) {
            return self.fields.count
        } else {
            return self.contentFields.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (tableView == self.tableView) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            
            let field = self.fields[indexPath.row]
            let parameter = self.parameters[indexPath.row]
            
            cell.addSubview(field)
            cell.addSubview(parameter)
            cell.selectionStyle = .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "contentCell", for: indexPath)
            cell.textLabel?.text = contentFields[indexPath.row]
            let parameter = self.contentParameters[indexPath.row]
            cell.addSubview(parameter)
            cell.selectionStyle = .none
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            if (tableView == self.tableView) {
                self.fields.remove(at: indexPath.row)
                self.parameters.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } else {
                self.contentFields.remove(at: indexPath.row)
                self.contentParameters.remove(at: indexPath.row)
                contentTableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    @objc func didAddContents(sender: UIButton) {
        if hasContent {
            self.contentTableView.isHidden = false
            self.contentLabel.isHidden = false
        }
    }
    
    
    @objc func didCreatePayload(sender: UIButton) {
        if let event = self.event as? TikTokContentsEvent {
            for fieldIndex in 0 ..< fields.count {
                let field = fields[fieldIndex]
                let parameter = self.parameters[fieldIndex]
                if parameter.text!.isEmpty {
                    continue
                }
                if field.text == "content_type" {
                    event.setContentType(parameter.text!)
                } else if field.text == "content_id" {
                    event.setContentId(parameter.text!)
                } else if field.text == "description" {
                    event.setDescription(parameter.text!)
                } else if field.text == "currency" {
                    event.setCurrency(TTCurrency(rawValue: parameter.text!))
                } else if field.text == "value" {
                    event.setValue(parameter.text!)
                } else {
                    event.addProperty(withKey: field.text!, value: parameter.text!)
                }
                    
            }
            if hasContent {
                let contentParams = TikTokContentParams()
                for contentIndex in 0 ..< contentFields.count {
                    let key = contentFields[contentIndex]
                    let parameter = self.contentParameters[contentIndex]
                    let value = parameter.text!
                    if value.isEmpty {
                        continue
                    }
                    if key == "price", let number = NumberFormatter().number(from: value) {
                        contentParams.price = NSNumber(value: number.floatValue)
                    } else if key == "quantity", let number = NumberFormatter().number(from: value) {
                        contentParams.quantity = NSInteger(number.intValue)
                    } else if key == "content_id" {
                        contentParams.contentId = value
                    } else if key == "content_category" {
                        contentParams.contentCategory = value
                    } else if key == "content_name" {
                        contentParams.contentName = value
                    } else if key == "brand" {
                        contentParams.brand = value
                    }
                }
                event.setContents([contentParams])
            }
            self.event = event
        } else {
            for fieldIndex in 0 ..< fields.count {
                let fieldText = fields[fieldIndex].text!
                let parameterText = self.parameters[fieldIndex].text!
                if parameterText.isEmpty {
                    continue
                }
                event.addProperty(withKey: fieldText, value: parameterText)
            }
                
        }
        parentVC?.eventToPost = self.event
        navigationController?.popViewController(animated: true)
        
    }
    
    @objc func addFieldToEvent(sender: UIButton) {
        let field = UITextField(frame: CGRect(x: 10, y: 5, width: 140, height: 30))
        field.borderStyle = .roundedRect
        field.tag = self.fields.count
        field.autocorrectionType = .no
        let parameter = UITextField(frame: CGRect(x: 160, y: 5, width: 200, height: 30))
        parameter.borderStyle = .roundedRect
        parameter.text = randomText(from: 5, to: 20)
        parameter.tag = self.fields.count
        parameter.autocorrectionType = .no
        
        
        self.fields.append(field)
        self.parameters.append(parameter)
        tableView.reloadData()
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    

}
