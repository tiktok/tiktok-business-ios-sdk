//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "TikTokConfig.h"
#import "TikTokDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokRequestHandler : NSObject

@property (atomic, strong, nullable) NSURLSession *session;
@property (atomic, strong) NSString *apiVersion;
@property (atomic, strong) NSString *apiDomain;

/**
 * @brief Method to obtain remote switch with completion handler
 */
- (void)getRemoteSwitch:(TikTokConfig *)config
        withCompletionHandler:(void (^)(BOOL isRemoteSwitchOn, BOOL isGlobalConfigFetched))completionHandler;

/**
 * @brief Method to interact with '/batch' endpoint
 */
- (void)sendBatchRequest:(NSArray *)eventsToBeFlushed
              withConfig:(TikTokConfig *)config;

/**
 * @brief Method to interact with '/app/monitor' endpoint
 */
- (void)sendCrashReport:(NSDictionary *)crashReport
             withConfig:(TikTokConfig *)config
  withCompletionHandler:(void (^)(void))completionHandler;

/**
 * @brief Method to get TikTok iOS SDK Version
 */
+ (NSString *)getSDKVersion;

/**
 * @brief Method to get TikTok iOS APP info
 */
+ (NSDictionary *)getAPPWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                                config:(TikTokConfig *)config;

/**
 * @brief Method to get iOS Device info
 */
+ (NSDictionary *)getDeviceInfo:(TikTokDeviceInfo *)deviceInfo
                     withConfig:(TikTokConfig *)config;

/**
 * @brief Method to get TikTok iOS SDK library info
 */
+ (NSDictionary *)getLibrary;

/**
 * @brief Method to get TikTok iOS user info
 */
+ (NSDictionary *)getUser;

/**
 * @brief Method to get user agent info
 */
+ (NSString *)getUserAgentWithDeviceInfo:(TikTokDeviceInfo *)deviceInfo;

@end

NS_ASSUME_NONNULL_END
