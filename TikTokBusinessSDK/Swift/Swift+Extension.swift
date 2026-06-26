//
//  Swift+Extension.swift
//  TikTokBusinessSDK
//
//  Created by Guanghui Liang on 2026/5/25.
//  Copyright © 2026 TikTok. All rights reserved.
    
@available(iOS 13.0, *)
extension AsyncSequence {
    func collect() async throws -> [Element] {
        try await reduce(into: [Element]()) { partialResult, element in
            partialResult.append(element)
        }
    }
}

extension Date {
    func convertToTimeStampString() -> String {
        return String(Int64(self.timeIntervalSince1970 * 1000))
    }
}
