//
//  DeeplinkViewController.swift
//  TikTokBusinessSDKTestApp
//
//  Created by TikTok on 2024/8/6.
//  Copyright © 2024 TikTok. All rights reserved.
//

import Foundation
import UIKit

class DeepLinkViewController: UIViewController {
    private let textView = UITextView()
    private let button = UIButton()
    private let titleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        titleLabel.text = "Enter DeepLink URL"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 20, y: 100, width: view.frame.width - 40, height: 30)
        view.addSubview(titleLabel)
        
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isScrollEnabled = true
        textView.textColor = .black
        textView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        textView.frame = CGRect(x: 20, y: 150, width: view.frame.width - 40, height: view.frame.height / 3)
        textView.autocapitalizationType = .none
        view.addSubview(textView)
        
        
        button.setTitle("open url", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        button.frame = CGRect(x: 20, y: view.frame.height / 3 + 170, width: view.frame.width - 40, height: 40)
        view.addSubview(button)
    }
    
    @objc private func buttonTapped() {
        if let url = textView.text, let deepLink = URL(string: url) {
            if UIApplication.shared.canOpenURL(deepLink) {
                UIApplication.shared.open(deepLink, options: [:], completionHandler: nil)
            } else {
                // can't open url
                print("Can't open this URL")
            }
        } else {
            // invalid url
            print("Please enter a valid URL")
        }
    }
}
