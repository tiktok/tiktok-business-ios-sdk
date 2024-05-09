//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokConfig.h"
#import "TikTokLogger.h"
#import "TikTokBusiness.h"
#import "TikTokFactory.h"
#import "TikTokUserAgentCollector.h"
#import "TikTokTypeUtility.h"

@interface TikTokConfig()

@property (nonatomic, weak) id<TikTokLogger> logger;
@property (nonatomic, assign) TikTokLogLevel logLevel;

@end

@implementation TikTokConfig: NSObject

+ (TikTokConfig *)configWithAccessToken:(nonnull NSString *)accessToken appId:(nonnull NSString *)appId tiktokAppId:(nonnull NSString *)tiktokAppId
{
    return [[TikTokConfig alloc] initWithAccessToken:accessToken appId:appId tiktokAppId:tiktokAppId];
}

+ (TikTokConfig *)configWithAppId:(nonnull NSString *)appId tiktokAppId:(nonnull NSString *)tiktokAppId
{
    return [[TikTokConfig alloc] initWithAppId:appId tiktokAppId:tiktokAppId];
}

- (void)disableTracking
{
    self.trackingEnabled = NO;
    [self.logger info:@"[TikTokConfig] Tracking: NO"];
}

- (void)disableAutomaticTracking
{
    self.automaticTrackingEnabled = NO;
    [self.logger info:@"[TikTokConfig] Auto Tracking: NO"];
}

- (void)disableInstallTracking
{
    self.installTrackingEnabled = NO;
    [self.logger info:@"[TikTokConfig] Install Tracking: NO"];
}

- (void)disableLaunchTracking
{
    self.launchTrackingEnabled = NO;
    [self.logger info:@"[TikTokConfig] Launch Tracking: NO"];
}

- (void)disableRetentionTracking
{
    self.retentionTrackingEnabled = NO;
    [self.logger info:@"[TikTokConfig] Retention Tracking: NO"];
}

- (void)disablePaymentTracking
{
    self.paymentTrackingEnabled = NO;
    [self.logger info:@"[TikTokConfig] Payment Tracking: NO"];
}

- (void)disableAppTrackingDialog
{
    self.appTrackingDialogSuppressed = YES;
    [self.logger info:@"[TikTokConfig] AppTrackingTransparency dialog has been suppressed"];
}

- (void)disableSKAdNetworkSupport
{
    self.SKAdNetworkSupportEnabled = NO;
    [self.logger info:@"[TikTokConfig] SKAdNetwork Support: NO"];
}

- (void)enableDebugMode
{
    self.debugModeEnabled = YES;
    [self.logger info:@"[TikTokConfig] debug mode has been opened"];
}

- (void)enableLDUMode
{
    self.LDUModeEnabled = YES;
    [self.logger info:@"[TikTokConfig] LDU mode has been opened"];
}

- (void)setCustomUserAgent: (NSString *)customUserAgent
{
    [[TikTokUserAgentCollector singleton] setUserAgent:customUserAgent];
    [self.logger info:@"[TikTokConfig] User Agent set to: %@", customUserAgent];
}

-(void)setLogLevel:(TikTokLogLevel)logLevel
{
    _logLevel = logLevel;
    [self.logger setLogLevel:logLevel];
}

- (void)setDelayForATTUserAuthorizationInSeconds: (long)seconds
{
    self.initialFlushDelay = seconds;
    [self.logger info:@"[TikTokConfig] Initial flush delay set to: %lu", seconds];
}

- (id)initWithAccessToken:(nonnull NSString *)accessToken appId:(nonnull NSString *)appId tiktokAppId:(nonnull NSString *)tiktokAppId
{
    self = [super init];
    
    if(self == nil) return nil;
    
    //regex check
    NSString *validAppId = [TikTokTypeUtility matchString:appId withRegex:@"^\\d*$"];
    NSString *validTTAppId = [TikTokTypeUtility matchString:tiktokAppId withRegex:@"^(\\d+,)*\\d+$"];
    
    _accessToken = accessToken;
    _appId = validAppId;
    _tiktokAppId = validTTAppId;
    _trackingEnabled = YES;
    _automaticTrackingEnabled = YES;
    _installTrackingEnabled = YES;
    _launchTrackingEnabled = YES;
    _retentionTrackingEnabled = YES;
    _paymentTrackingEnabled = YES;
    _appTrackingDialogSuppressed = NO;
    _SKAdNetworkSupportEnabled = YES;
    _debugModeEnabled = NO;
    
    self.logger = [TikTokFactory getLogger];
    return self;
}

- (id)initWithAppId:(nonnull NSString *)appId tiktokAppId:(nonnull NSString *)tiktokAppId
{
    self = [super init];
    
    if(self == nil) return nil;
    
    //regex check
    NSString *validAppId = [TikTokTypeUtility matchString:appId withRegex:@"^\\d*$"];
    NSString *validTTAppId = [TikTokTypeUtility matchString:tiktokAppId withRegex:@"^(\\d+,)*\\d+$"];
    
    _accessToken = @"";
    _appId = validAppId;
    _tiktokAppId = validTTAppId;
    _trackingEnabled = YES;
    _automaticTrackingEnabled = YES;
    _installTrackingEnabled = YES;
    _launchTrackingEnabled = YES;
    _retentionTrackingEnabled = YES;
    _paymentTrackingEnabled = YES;
    _appTrackingDialogSuppressed = NO;
    _SKAdNetworkSupportEnabled = YES;
    _debugModeEnabled = NO;
    
    self.logger = [TikTokFactory getLogger];
    return self;
}

@end
