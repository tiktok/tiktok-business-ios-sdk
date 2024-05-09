//
//  IdentifyViewController.swift
//  TikTokBusinessSDKTestApp
//
//  Created by TikTok on 2024/3/11.
//  Copyright © 2024 TikTok. All rights reserved.
//

import Foundation
import UIKit
import TikTokBusinessSDK

class IdentifyViewController: UIViewController {

    var externalIDTextField: UITextField!
    var emailTextField: UITextField!
    var phoneTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let screenWidth = view.frame.width
        let elementWidth: CGFloat = 200
        let elementHeight: CGFloat = 40
        let verticalSpacing: CGFloat = 50
        
        let centerX = (screenWidth - elementWidth) / 2
        
        externalIDTextField = UITextField(frame: CGRect(x: centerX, y: 100, width: elementWidth, height: elementHeight))
        externalIDTextField.placeholder = "External ID"
        externalIDTextField.borderStyle = .roundedRect
        view.addSubview(externalIDTextField)
        
        emailTextField = UITextField(frame: CGRect(x: centerX, y: 100 + verticalSpacing, width: elementWidth, height: elementHeight))
        emailTextField.placeholder = "Email"
        emailTextField.borderStyle = .roundedRect
        view.addSubview(emailTextField)
        
        phoneTextField = UITextField(frame: CGRect(x: centerX, y: 100 + 2 * verticalSpacing, width: elementWidth, height: elementHeight))
        phoneTextField.placeholder = "Phone"
        phoneTextField.borderStyle = .roundedRect
        view.addSubview(phoneTextField)

        let buttonWidth: CGFloat = 100
        let buttonHeight: CGFloat = 40
        let buttonSpacing: CGFloat = 20
        let cornerRadius: CGFloat = 10
        let bgColor: UIColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        
        // 计算按钮的起始 x 坐标
        let startX = (screenWidth - 3 * buttonWidth - 2 * buttonSpacing) / 2
        
        // 创建 Reset 按钮
        let resetButton = UIButton(type: .system)
        resetButton.frame = CGRect(x: startX, y: 100 + 3 * verticalSpacing, width: buttonWidth, height: buttonHeight)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = bgColor
        resetButton.layer.cornerRadius = cornerRadius
        resetButton.addTarget(self, action: #selector(resetFields), for: .touchUpInside)
        view.addSubview(resetButton)
        
        let identifyButton = UIButton(type: .system)
        identifyButton.frame = CGRect(x: startX + buttonWidth + buttonSpacing, y: 100 + 3 * verticalSpacing, width: buttonWidth, height: buttonHeight)
        identifyButton.setTitle("Identify", for: .normal)
        identifyButton.setTitleColor(.white, for: .normal)
        identifyButton.backgroundColor = bgColor
        identifyButton.layer.cornerRadius = cornerRadius
        identifyButton.addTarget(self, action: #selector(identify), for: .touchUpInside)
        view.addSubview(identifyButton)
        
        // 创建 Logout 按钮
        let logoutButton = UIButton(type: .system)
        logoutButton.frame = CGRect(x: startX + 2 * (buttonWidth + buttonSpacing), y: 100 + 3 * verticalSpacing, width: buttonWidth, height: buttonHeight)
        logoutButton.setTitle("Logout", for: .normal)
        logoutButton.setTitleColor(.white, for: .normal)
        logoutButton.backgroundColor = bgColor
        logoutButton.layer.cornerRadius = cornerRadius
        logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)
        view.addSubview(logoutButton)
    }


    @objc func resetFields() {
        externalIDTextField.text = ""
        emailTextField.text = ""
        phoneTextField.text = ""
    }

    @objc func identify() {
        let externalID = externalIDTextField.text ?? ""
        let email = emailTextField.text ?? ""
        let phone = phoneTextField.text ?? ""

        TikTokBusiness.identify(withExternalID: externalID, phoneNumber: phone, email: email)
    }

    @objc func logout() {
        externalIDTextField.text = ""
        emailTextField.text = ""
        phoneTextField.text = ""

        TikTokBusiness.logout()
    }
}
