//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "TikTokLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokConfig : NSObject

@property (nonatomic, copy, readonly, nonnull) NSString *accessToken;
@property (nonatomic, copy, readonly, nonnull) NSString *appId;
@property (nonatomic, readonly) NSString * tiktokAppId;
@property (nonatomic, assign) BOOL trackingEnabled;
@property (nonatomic, assign) BOOL automaticTrackingEnabled;
@property (nonatomic, assign) BOOL installTrackingEnabled;
@property (nonatomic, assign) BOOL launchTrackingEnabled;
@property (nonatomic, assign) BOOL retentionTrackingEnabled;
@property (nonatomic, assign) BOOL paymentTrackingEnabled;
@property (nonatomic, assign) BOOL appTrackingDialogSuppressed DEPRECATED_MSG_ATTRIBUTE("Deprecated. SDK won't actively call ATT dialog. Use requestTrackingAuthorizationWithCompletionHandler if needed");
@property (nonatomic, assign) BOOL SKAdNetworkSupportEnabled;
@property (nonatomic, assign) BOOL debugModeEnabled;
@property (nonatomic, assign) BOOL LDUModeEnabled;
@property (nonatomic, assign) BOOL autoEDPEventEnabled;
@property (nonatomic, assign) BOOL isLowPerf;
@property (nonatomic) long initialFlushDelay;

+ (nullable TikTokConfig *)configWithAccessToken:(nonnull NSString *)accessToken
                                           appId:(nonnull NSString *)appId
                                     tiktokAppId:(nonnull NSString *)tiktokAppId;

- (void)disableTracking;
- (void)disableAutomaticTracking;
- (void)disableInstallTracking;
- (void)disableLaunchTracking;
- (void)disableRetentionTracking;
- (void)disablePaymentTracking;
- (void)disableAppTrackingDialog DEPRECATED_MSG_ATTRIBUTE("Deprecated. SDK won't actively call ATT dialog. Use requestTrackingAuthorizationWithCompletionHandler if needed");
- (void)disableSKAdNetworkSupport;
- (void)disableAutoEnhancedDataPostbackEvent;
- (void)setCustomUserAgent:(NSString *)customUserAgent;
- (void)setLogLevel:(TikTokLogLevel)logLevel;
- (void)setDelayForATTUserAuthorizationInSeconds:(long)seconds;
- (void)enableDebugMode;
- (void)enableLDUMode;
- (void)setIsLowPerformanceDevice:(BOOL)isLow;

- (nullable id)initWithAppId:(nonnull NSString *)appId
                       tiktokAppId:(nonnull NSString *)tiktokAppId;

@end

NS_ASSUME_NONNULL_END
