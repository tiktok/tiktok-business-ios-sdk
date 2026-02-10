//
//  TikTokDefaults.h
//  TikTokBusinessSDK
//
//  Copyright © 2025 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Storage for TikTok Business SDK preferences.
 * Uses a dedicated UserDefaults suite (separate from standardUserDefaults).
 * Call [TikTokDefaults storage] to get the shared NSUserDefaults instance.
 */
@interface TikTokDefaults : NSObject

/**
 * Returns the shared NSUserDefaults instance for the SDK.
 * Uses suite name "com.tiktok.business.sdk". Initialized once on first call.
 */
+ (NSUserDefaults *)storage;

@end

NS_ASSUME_NONNULL_END
