//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import "TikTokDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice(TikTokAdditions)

- (BOOL)tiktokUserTrackingEnabled;
- (NSString *)tiktokDeviceType;
- (NSString *)tiktokDeviceName;
- (NSString *)tiktokCreateUuid;
- (NSString *)tiktokVendorId;
- (NSString *)tiktokDeviceIp;
- (void)requestTrackingAuthorizationWithCompletionHandler: (void(^)(NSUInteger status))completion;
- (NSString *)getIPAddress:(BOOL)preferIPv4;
- (NSDictionary *)getIPAddresses;

@end

NS_ASSUME_NONNULL_END
