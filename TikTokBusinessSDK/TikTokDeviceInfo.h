//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Used to fetch device level information
*/
@interface TikTokDeviceInfo : NSObject

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *appNamespace;
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy) NSString *appBuild;
@property (nonatomic, copy) NSString *devicePlatform;
@property (nonatomic, copy) NSString *deviceIdForAdvertisers;
@property (nonatomic, copy) NSString *deviceVendorId;
@property (nonatomic, copy) NSString *localeInfo;
@property (nonatomic, copy) NSString *ipInfo;
@property (nonatomic, assign) BOOL trackingEnabled;
@property (nonatomic, copy) NSString *clientSdk;
@property (nonatomic, copy) NSString *deviceType;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *systemVersion;
@property (nonatomic, copy) NSString *machineModel;
@property (nonatomic, copy) NSString *cpuSubType;
@property (nonatomic, copy) NSString *osBuild;

- (id)initWithSdkPrefix:(NSString *)sdkPrefix;
+ (TikTokDeviceInfo *)deviceInfoWithSdkPrefix:(NSString *)sdkPrefix;
- (NSString *)getUserAgent;
- (NSString *)fallbackUserAgent;

@end

NS_ASSUME_NONNULL_END
