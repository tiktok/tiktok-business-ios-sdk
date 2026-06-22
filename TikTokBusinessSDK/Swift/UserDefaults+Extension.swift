//
//  UserDefaults+Extension.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/5/25.
//  Copyright © 2026 TikTok. All rights reserved.
    

extension UserDefaults {
    /// UserDefaults's the partition for TikTokBusinessSDK    
    static let tiktokBusiness: UserDefaults = .init(suiteName: "TikTokBusinessSDK") ?? .standard
}
