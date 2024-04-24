//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

import UIKit
/* ADD IMPORT STATEMENT HERE */
import TikTokBusinessSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Overriding Layout Constraint Warning Messages in Test App
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        /* POPULATE WITH ACCESS TOKEN, APPLICATION ID AND TIKTOK APPLICATION ID IN CONFIG */
        let config = TikTokConfig.init(appId: nil, tiktokAppId: nil)
//        let config = TikTokConfig.init(accessToken: "d5db46888d3884b1b91b1b77542b16514e788f6f", appId: "", tiktokAppId: )
        config?.setLogLevel(TikTokLogLevelVerbose)          // Set Log Level
        /* UNCOMMENT TO CUSTOMIZE OPTIONS BEFORE INITIALIZING SDK
        
        config?.disableTracking()                           // Disable All Tracking
        config?.disableAutomaticTracking()                  // Disable All Automatic Tracking
        config?.disableInstallTracking()                    // Disable Automatic Install Tracking
        config?.disableLaunchTracking()                     // Disable Automatic Launch Tracking
        config?.disableRetentionTracking()                  // Disable Automatic 2DRetention Tracking
        config?.disablePaymentTracking()                    // Disable Automatic Payment Tracking
        config?.disableAppTrackingDialog()                  // Disable App Tracking Transparency Dialog
        config?.disableSKAdNetworkSupport()                 // Disable SKAdNetwork Support
        config?.setLogLevel(TikTokLogLevelVerbose)          // Set Log Level
        config?.setCustomUserAgent("CUSTOM USER AGENT")     // Set Custom User Agent Collection
        config?.setDelayForATTUserAuthorizationInSeconds(20) // Set delay for ATT

        */
        /* ADD LINE HERE */
        TikTokBusiness.initializeSdk(config)
        
        /* UNCOMMENT TO CUSTOMIZE AFTER INITIALIZING SDK
 
        TikTokBusiness.setTrackingEnabled(/* value */)
        TikTokBusiness.setCustomUserAgent("THIS IS A CUSTOM USER AGENT")
        
        */
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

