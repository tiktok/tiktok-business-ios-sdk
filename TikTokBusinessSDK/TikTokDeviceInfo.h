//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN



typedef NS_ENUM(NSInteger, TTDeviceDarkMode) {
    TTDeviceDarkModeUnspecified = -1,
    TTDeviceDarkModeLight = 0,
    TTDeviceDarkModeDark = 1,
};

typedef NS_ENUM(NSInteger, TTDeviceAirplaneStatus) {
    TTDeviceAirplaneStatusUnknown = -1,
    TTDeviceAirplaneStatusClose = 0,
    TTDeviceAirplaneStatusOpen = 1,
};

typedef NS_ENUM(NSInteger, TTDeviceHeadset) {
    TTDeviceHeadsetUnspecified = -1,
    TTDeviceHeadsetNoConnect = 0,
    TTDeviceHeadsetConnect = 1,
}; //wire headset plugged in

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
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *systemVersion;
@property (assign, assign) TTDeviceAirplaneStatus airplane;
@property (atomic, assign) TTDeviceDarkMode darkmode;
@property (atomic, assign) TTDeviceHeadset headset;
@property (atomic, assign) NSInteger systemVolume;

+ (TikTokDeviceInfo *)deviceInfo;
- (void)updateIdentifier;
- (NSString *)getUserAgent;
- (NSString *)fallbackUserAgent;

@end

NS_ASSUME_NONNULL_END
