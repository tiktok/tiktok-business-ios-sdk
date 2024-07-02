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
        withCompletionHandler:(void (^)(BOOL isRemoteSwitchOn, NSDictionary *globalConfig))completionHandler;

/**
 * @brief Method to interact with '/batch' endpoint
 */
- (void)sendBatchRequest:(NSArray *)eventsToBeFlushed
              withConfig:(TikTokConfig *)config;

/**
 * @brief Method to interact with '/app/monitor' endpoint
 */
- (void)sendMonitorRequest:(NSArray *)eventsToBeFlushed
                withConfig:(TikTokConfig *)config;

@end

NS_ASSUME_NONNULL_END
