//
//  InitViewController.swift
//  TikTokBusinessSDKTestApp
//
//  Created by TikTok on 2024/3/11.
//  Copyright © 2024 TikTok. All rights reserved.
//

import Foundation
import UIKit
import TikTokBusinessSDK

class InitViewController: UIViewController {

    var appIdTextField: UITextField!
    var ttAppIdTextField: UITextField!
    var tokenTextField: UITextField!
    var debugModeEnabledSwitch: UISwitch!
    var trackingEnabledswitch: UISwitch!
    var automaticTrackingEnabledswitch: UISwitch!
    var installTrackingEnabledswitch: UISwitch!
    var launchTrackingEnabledSwitch: UISwitch!
    var retentionTrackingEnabledSwitch: UISwitch!
    var paymentTrackingEnabledSwitch: UISwitch!
    var autoEDPEventSwitch: UISwitch!
    var SKAdNetworkSupportEnabledSwitch: UISwitch!
    var LDUModeEnabledSwitch: UISwitch!
    var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        appIdTextField = UITextField(frame: CGRect(x: 20, y: 100, width: 200, height: 40))
        appIdTextField.placeholder = "Enter App ID"
        appIdTextField.borderStyle = .roundedRect
        view.addSubview(appIdTextField)

        ttAppIdTextField = UITextField(frame: CGRect(x: 20, y: 150, width: 200, height: 40))
        ttAppIdTextField.placeholder = "Enter TikTokAppID"
        ttAppIdTextField.borderStyle = .roundedRect
        view.addSubview(ttAppIdTextField)
        
        tokenTextField = UITextField(frame: CGRect(x: 20, y: 200, width: 200, height: 40))
        tokenTextField.placeholder = "Enter access token"
        tokenTextField.borderStyle = .roundedRect
        view.addSubview(tokenTextField)
        
        // Debug Mode Enabled
        debugModeEnabledSwitch = UISwitch()
        debugModeEnabledSwitch.frame = CGRect(x: 230, y: 100, width: 50, height: 30)
        debugModeEnabledSwitch.isOn = true
        view.addSubview(debugModeEnabledSwitch)
        
        let debugModeEnabledLabel = UILabel(frame: CGRect(x: 290, y: 100, width: 100, height: 30))
        debugModeEnabledLabel.text = "DebugMode"
        view.addSubview(debugModeEnabledLabel)
        
        // Tracking Enabled
        trackingEnabledswitch = UISwitch()
        trackingEnabledswitch.frame = CGRect(x: 20, y: 250, width: 50, height: 30)
        trackingEnabledswitch.isOn = true
        view.addSubview(trackingEnabledswitch)

        let trackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 250, width: 250, height: 30))
        trackingEnabledLabel.text = "Tracking Enabled"
        view.addSubview(trackingEnabledLabel)
        
        // Automatic Tracking Enabled
        automaticTrackingEnabledswitch = UISwitch()
        automaticTrackingEnabledswitch.frame = CGRect(x: 20, y: 290, width: 50, height: 30)
        automaticTrackingEnabledswitch.isOn = true
        view.addSubview(automaticTrackingEnabledswitch)

        let automaticTrackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 290, width: 250, height: 30))
        automaticTrackingEnabledLabel.text = "Automatic Tracking Enabled"
        view.addSubview(automaticTrackingEnabledLabel)
        
        // Install Tracking Enabled
        installTrackingEnabledswitch = UISwitch()
        installTrackingEnabledswitch.frame = CGRect(x: 20, y: 330, width: 50, height: 30)
        installTrackingEnabledswitch.isOn = true
        view.addSubview(installTrackingEnabledswitch)

        let installTrackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 330, width: 250, height: 30))
        installTrackingEnabledLabel.text = "Install Tracking Enabled"
        view.addSubview(installTrackingEnabledLabel)
        
        // Launch Tracking Enabled
        launchTrackingEnabledSwitch = UISwitch()
        launchTrackingEnabledSwitch.frame = CGRect(x: 20, y: 370, width: 50, height: 30)
        launchTrackingEnabledSwitch.isOn = true
        view.addSubview(launchTrackingEnabledSwitch)
        
        let launchTrackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 370, width: 250, height: 30))
        launchTrackingEnabledLabel.text = "Launch Tracking Enabled"
        view.addSubview(launchTrackingEnabledLabel)
        
        // Retention Tracking Enabled
        retentionTrackingEnabledSwitch = UISwitch()
        retentionTrackingEnabledSwitch.frame = CGRect(x: 20, y: 410, width: 50, height: 30)
        retentionTrackingEnabledSwitch.isOn = true
        view.addSubview(retentionTrackingEnabledSwitch)
        
        let retentionTrackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 410, width: 250, height: 30))
        retentionTrackingEnabledLabel.text = "Retention Tracking Enabled"
        view.addSubview(retentionTrackingEnabledLabel)
                
        // Payment Tracking Enabled
        paymentTrackingEnabledSwitch = UISwitch()
        paymentTrackingEnabledSwitch.frame = CGRect(x: 20, y: 450, width: 50, height: 30)
        paymentTrackingEnabledSwitch.isOn = true
        view.addSubview(paymentTrackingEnabledSwitch)
        
        let paymentTrackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 450, width: 250, height: 30))
        paymentTrackingEnabledLabel.text = "Payment Tracking Enabled"
        view.addSubview(paymentTrackingEnabledLabel)
        
        // Auto EDP Events Suppressed
        autoEDPEventSwitch = UISwitch()
        autoEDPEventSwitch.frame = CGRect(x: 20, y: 490, width: 50, height: 30)
        autoEDPEventSwitch.isOn = true
        view.addSubview(autoEDPEventSwitch)
        
        let autoEDPTrackingEnabledLabel = UILabel(frame: CGRect(x: 80, y: 490, width: 250, height: 30))
        autoEDPTrackingEnabledLabel.text = "Auto EDP events Tracking Enabled"
        view.addSubview(autoEDPTrackingEnabledLabel)
        
        // SKAdNetwork Support Enabled
        SKAdNetworkSupportEnabledSwitch = UISwitch()
        SKAdNetworkSupportEnabledSwitch.frame = CGRect(x: 20, y: 530, width: 50, height: 30)
        SKAdNetworkSupportEnabledSwitch.isOn = true
        view.addSubview(SKAdNetworkSupportEnabledSwitch)
        
        let SKAdNetworkSupportEnabledLabel = UILabel(frame: CGRect(x: 80, y: 530, width: 250, height: 30))
        SKAdNetworkSupportEnabledLabel.text = "SKAdNetwork Support Enabled"
        view.addSubview(SKAdNetworkSupportEnabledLabel)
        
        // LDU Mode Enabled
        LDUModeEnabledSwitch = UISwitch()
        LDUModeEnabledSwitch.frame = CGRect(x: 20, y: 570, width: 50, height: 30)
        LDUModeEnabledSwitch.isOn = false
        view.addSubview(LDUModeEnabledSwitch)
        
        let LDUModeEnabledLabel = UILabel(frame: CGRect(x: 80, y: 570, width: 250, height: 30))
        LDUModeEnabledLabel.text = "LDU Mode Enabled"
        view.addSubview(LDUModeEnabledLabel)

        let initButton = UIButton(type: .system)
        initButton.frame = CGRect(x: 20, y: 610, width: 180, height: 40)
        initButton.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        initButton.setTitleColor(.white, for: .normal)
        initButton.layer.cornerRadius = 10
        initButton.setTitle("Initialize SDK", for: .normal)
        initButton.addTarget(self, action: #selector(initSDK), for: .touchUpInside)
        view.addSubview(initButton)
        
        statusLabel = UILabel(frame: CGRect(x: 20, y: 620, width: 300, height: 100))
        statusLabel.numberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.text = TikTokBusiness.isInitialized() ? "SDK initialized" : "SDK not initialized"
        view.addSubview(statusLabel)
    }

    @objc func initSDK() {
        if let appId = appIdTextField.text, let ttAppId = ttAppIdTextField.text, let accessToken = tokenTextField.text {
            /* POPULATE WITH ACCESS TOKEN, APPLICATION ID AND TIKTOK APPLICATION ID IN CONFIG */

            let config = TikTokConfig(accessToken: accessToken, appId: appId, tiktokAppId: ttAppId)
            
            config?.setLogLevel(TikTokLogLevelVerbose)          // Set Log Level
            if !trackingEnabledswitch.isOn {
                config?.disableTracking()                       // Disable All Tracking
            }
            if !trackingEnabledswitch.isOn {
                config?.disableTracking()                       // Disable All Tracking
            }
            if !automaticTrackingEnabledswitch.isOn {
                config?.disableAutomaticTracking()              // Disable All Automatic Tracking
            }
            if !installTrackingEnabledswitch.isOn {
                config?.disableInstallTracking()                // Disable Automatic Install Tracking
            }
            if !launchTrackingEnabledSwitch.isOn {
                config?.disableLaunchTracking()                 // Disable Automatic Launch Tracking
            }
            if !paymentTrackingEnabledSwitch.isOn {
                config?.disablePaymentTracking()                // Disable Automatic Payment Tracking
            }
            if !retentionTrackingEnabledSwitch.isOn {
                config?.disableRetentionTracking()              // Disable Automatic 2DRetention Tracking
            }
            if !autoEDPEventSwitch.isOn {
                config?.disableAutoEnhancedDataPostbackEvent()  // Disable Auto EDP events Tracking
            }
            if !SKAdNetworkSupportEnabledSwitch.isOn {
                config?.disableSKAdNetworkSupport()             // Disable SKAdNetwork Support
            }
            if debugModeEnabledSwitch.isOn {
                config?.enableDebugMode()                       // Enable Debug Mode
            }
            if LDUModeEnabledSwitch.isOn {
                config?.enableLDUMode()                         // Enable Limited Data Use Mode
            }
            /* UNCOMMENT TO CUSTOMIZE OPTIONS BEFORE INITIALIZING SDK
            config?.setCustomUserAgent("CUSTOM USER AGENT")     // Set Custom User Agent Collection
            config?.setDelayForATTUserAuthorizationInSeconds(20) // Set delay for ATT

            */
            /* ADD LINE HERE */
            TikTokBusiness.initializeSdk(config) { success, error in
                if (!success) {
                    print(error!.localizedDescription)
                } else {
                    self.statusLabel.text = "SDK initialized"
                }
            }
            
            /* UNCOMMENT TO CUSTOMIZE AFTER INITIALIZING SDK
     
            TikTokBusiness.setTrackingEnabled(/* value */)
            TikTokBusiness.setCustomUserAgent("THIS IS A CUSTOM USER AGENT")
            
            */
        } else {
            print("Please enter AppId and TikTokAppId")
        }
    }
}
