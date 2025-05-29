//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

/**
 * Import headers for Apple's App Tracking Transparency Requirements
 * - Default: App Tracking Dialog is shown to the user
 * - Use suppressAppTrackingDialog flag while initializing TikTokConfig to disable IDFA collection
*/
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokConfig.h"
#import "TikTokLogger.h"
#import "TikTokAppEvent.h"
#import "TikTokPaymentObserver.h"
#import "TikTokFactory.h"
#import "TikTokErrorHandler.h"
#import "TikTokIdentifyUtility.h"
#import "TikTokUserAgentCollector.h"
#import "TikTokSKAdNetworkSupport.h"
#import "UIDevice+TikTokAdditions.h"
#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokBusinessSDKMacros.h"
#import "UIViewController+TikTokAdditions.h"
#import "TikTokViewUtility.h"
#import "TikTokRequestHandler.h"
#import "TikTokTypeUtility.h"
#import "TikTokEDPConfig.h"
#import "TTSDKCrash.h"
#import "TTSDKCrashInstallationConsole.h"
#import "TTSDKCrashConfiguration.h"
#import "TTSDKCrashReport.h"
#import "TikTokBusinessSDKAddress.h"
#import "TikTokBaseEventPersistence.h"
#import "TikTokSKANEventPersistence.h"

@interface TikTokBusiness()

@property (nonatomic, weak) id<TikTokLogger> logger;
@property (nonatomic) BOOL initialized;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL trackingEnabled;
@property (nonatomic) BOOL automaticTrackingEnabled;
@property (nonatomic) BOOL installTrackingEnabled;
@property (nonatomic) BOOL launchTrackingEnabled;
@property (nonatomic) BOOL retentionTrackingEnabled;
@property (nonatomic) BOOL paymentTrackingEnabled;
@property (nonatomic) BOOL appTrackingDialogSuppressed;
@property (nonatomic) BOOL SKAdNetworkSupportEnabled;
@property (nonatomic, strong, nullable) TikTokRequestHandler *requestHandler;
@property (nonatomic, strong, readwrite) dispatch_queue_t isolationQueue;
@property (nonatomic, assign, readwrite) BOOL isDebugMode;
@property (nonatomic, copy) NSString *testEventCode;
@property (nonatomic, assign, readwrite) BOOL isLDUMode;
@property (nonatomic, strong, nullable) TikTokConfig *config;
@property (nonatomic, assign) BOOL remoteDebugEnabled;
@property (nonatomic, strong, nullable) NSTimer *sessionActivityTimer;

@end


@implementation TikTokBusiness: NSObject

#pragma mark - Object Lifecycle Methods

static TikTokBusiness * defaultInstance = nil;
static dispatch_once_t onceToken = 0;

+ (instancetype)getInstance
{
    dispatch_once(&onceToken, ^{
        defaultInstance = [[self alloc] init];
    });
    return defaultInstance;
}

+ (void)resetInstance
{
  if (onceToken) {
    onceToken = 0;
  }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopTimer];
}

- (void)stopTimer {
    if (self.sessionActivityTimer) {
        [self.sessionActivityTimer invalidate];
        self.sessionActivityTimer = nil;
    }
}

- (void)startTimer {
    self.sessionActivityTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                           target:self
                                                         selector:@selector(checkSessionActivity)
                                                         userInfo:nil
                                                          repeats:YES];
             [[NSRunLoop currentRunLoop] addTimer:self.sessionActivityTimer forMode:NSRunLoopCommonModes];
}

- (void)checkSessionActivity {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateActive) {
        NSNumber *currentTS = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        NSDictionary *meta = @{
            @"ts": currentTS,
        };
        NSDictionary *monitorSessionActivityProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"session_activity",
            @"meta": meta
        };
        TikTokAppEvent *monitorSessionActivityEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorSessionActivityProperties withType:@"monitor"];
        @synchronized (self) {
            [self.eventLogger addEvent:monitorSessionActivityEvent];
        }
    }
}

- (id)init
{
    self = [super init];
    if(self == nil) {
        return nil;
    }
    
    self.isolationQueue = dispatch_queue_create([@"tiktokIsolationQueue" UTF8String], DISPATCH_QUEUE_SERIAL);
    self.requestHandler = nil;
    self.logger = [TikTokFactory getLogger];
    self.enabled = YES;
    self.trackingEnabled = YES;
    self.automaticTrackingEnabled = YES;
    self.installTrackingEnabled = YES;
    self.launchTrackingEnabled = YES;
    self.retentionTrackingEnabled = YES;
    self.paymentTrackingEnabled = YES;
    self.appTrackingDialogSuppressed = NO;
    self.SKAdNetworkSupportEnabled = YES;
    self.exchangeErrReportRate = 0.01;
    self.isRemoteSwitchOn = YES;
    self.remoteDebugEnabled = NO;
    
    [self checkAttStatus];

    return self;
}

#pragma mark - Public static methods

+ (void)initializeSdk:(TikTokConfig *)tiktokConfig
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] initializeSdk: tiktokConfig completionHandler:nil];
    }
}

+ (void)initializeSdk: (nullable TikTokConfig *)tiktokConfig completionHandler:(void (^)(BOOL success, NSError * _Nullable error))completionHandler {
    [[TikTokBusiness getInstance] initializeSdk: tiktokConfig completionHandler:completionHandler];
}

+ (void)trackEvent:(NSString *)eventName
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] trackEvent:eventName];
    }
}

+ (void)trackEvent:(NSString *)eventName
    withProperties:(NSDictionary *)properties
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] trackEvent:eventName withProperties:properties withId:@""];
    }
}

+ (void)trackEvent:(NSString *)eventName
withType:(NSString *)type
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] trackEvent:eventName withType:type];
    }
}

+ (void)trackEvent: (NSString *)eventName withId: (NSString *)eventId {
    @synchronized (self) {
        [[TikTokBusiness getInstance] trackEvent:eventName withId:eventId];
    }
}

+ (void)trackTTEvent: (TikTokBaseEvent *)event {
    @synchronized (self) {
        [[TikTokBusiness getInstance] trackTTEvent:event];
    }
}

+ (void)setTrackingEnabled:(BOOL)enabled
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] setTrackingEnabled:enabled];
    }
}

+ (void)setCustomUserAgent:(NSString *)customUserAgent
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] setCustomUserAgent:customUserAgent];
    }
}

+ (void)updateAccessToken:(nonnull NSString *)accessToken
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] updateAccessToken:accessToken];
    }
}

+ (NSString *)idfa {
    @synchronized (self) {
        return [[TikTokBusiness getInstance] idfa];
    }
}

+ (void)identifyWithExternalID:(nullable NSString *)externalID
              externalUserName:(nullable NSString *)externalUserName
                   phoneNumber:(nullable NSString *)phoneNumber
                         email:(nullable NSString *)email
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] identifyWithExternalID:externalID externalUserName:externalUserName phoneNumber:phoneNumber email:email];
        
    }
}

+ (void)logout
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] logout];
    }
}

+ (void)explicitlyFlush
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] explicitlyFlush];
    }
}

+ (BOOL)appInForeground
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] appInForeground];
    }
}

+ (BOOL)appInBackground
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] appInBackground];
    }
}

+ (BOOL)appIsInactive
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] appIsInactive];
    }
}

+ (BOOL)isTrackingEnabled
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] isTrackingEnabled];
    }
}

+ (BOOL)isUserTrackingEnabled
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] isUserTrackingEnabled];
    }
}

+ (BOOL)isInitialized {
    @synchronized (self) {
        return [[TikTokBusiness getInstance] isInitialized];
    }
}

+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^_Nullable)(NSUInteger status))completion
{
    NSString *trackingDesc = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserTrackingUsageDescription"];
    if (@available(iOS 14, *)) {
        if (trackingDesc) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                if(completion) {
                    completion(status);
                }
            }];
        } else {
            [[TikTokFactory getLogger] warn:@"Please set NSUserTrackingUsageDescription in Property List before calling App Tracking Dialog"];
        }
    } else {
        // Fallback on earlier versions
    }
}

+ (TikTokEventLogger *)getEventLogger
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] eventLogger];
    }
}

+ (BOOL)isDebugMode
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] isDebugMode];
    }
}

+ (NSString *)getTestEventCode
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] testEventCode];
    }
}

+ (BOOL)isLDUMode
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] isLDUMode];
    }
}

+ (void)fetchDeferredDeeplinkWithCompletion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion {
    [[TikTokBusiness getInstance] fetchDeferredDeeplinkWithCompletion:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (completion) {
            completion(url, error);
        }
    }];
}

// MARK: - private

- (void)initializeSdk:(TikTokConfig *)tiktokConfig completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler
{
    if (self.eventLogger != nil) {
        [self.logger warn:@"TikTok SDK has been initialized already!"];
        return;
    }
    NSNumber *initStartTimestamp = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    if (!TTCheckValidString(tiktokConfig.appId) || !TTCheckValidString(tiktokConfig.tiktokAppId)) {
        NSNumber *initEndTimestamp = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        NSDictionary *configMonitorEndMeta = @{
            @"ts": initStartTimestamp,
            @"latency": [NSNumber numberWithLongLong:([initEndTimestamp longLongValue] - [initStartTimestamp longLongValue])],
            @"success": [NSNumber numberWithBool:false]
        };
        NSDictionary *configMonitorEndProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"config_api",
            @"meta": configMonitorEndMeta
        };
        TikTokAppEvent *configMonitorEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:configMonitorEndProperties withType:@"monitor"];
        [[TikTokMonitorEventPersistence persistence] persistEvents:@[configMonitorEndEvent]];
        
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                 code:-2
                                             userInfo:@{
                NSLocalizedDescriptionKey : @"Invalid appId or tiktokAppId, SDK not initialized",
            }];
            completionHandler(NO, error);
        }
        return;
    }
    
    self.config = tiktokConfig;
    self.trackingEnabled = tiktokConfig.trackingEnabled;
    self.automaticTrackingEnabled = tiktokConfig.automaticTrackingEnabled;
    self.installTrackingEnabled = tiktokConfig.installTrackingEnabled;
    self.launchTrackingEnabled = tiktokConfig.launchTrackingEnabled;
    self.retentionTrackingEnabled = tiktokConfig.retentionTrackingEnabled;
    self.paymentTrackingEnabled = tiktokConfig.paymentTrackingEnabled;
    self.appTrackingDialogSuppressed = tiktokConfig.appTrackingDialogSuppressed;
    self.SKAdNetworkSupportEnabled = tiktokConfig.SKAdNetworkSupportEnabled;
    self.accessToken = tiktokConfig.accessToken;
    NSString *anonymousID = [[TikTokIdentifyUtility sharedInstance] getOrGenerateAnonymousID];
    self.anonymousID = anonymousID;
    self.isDebugMode = tiktokConfig.debugModeEnabled;
    self.testEventCode = self.isDebugMode ? [self generateTestEventCodeWithConfig:tiktokConfig] : nil;
    self.isLDUMode = tiktokConfig.LDUModeEnabled;

    self.requestHandler = [TikTokFactory getRequestHandler];
    self.eventLogger = [[TikTokEventLogger alloc] initWithConfig:tiktokConfig];
    self.initialized = NO;
    [self startTimer];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"true" forKey:@"AreTimersOn"];
    [defaults setObject:initStartTimestamp forKey:@"monitorInitStartTime"];
    [defaults synchronize];
    
    [self getGlobalConfig:tiktokConfig isFirstInitialization:YES];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    if (completionHandler) {
        if (!tiktokConfig.trackingEnabled) {
            NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                                 code:-1
                                             userInfo:@{
                NSLocalizedDescriptionKey : @"tracking not enabled, SDK not initialized",
            }];
            completionHandler(NO, error);
        } else {
            self.initialized = YES;
            completionHandler(YES, nil);
        }
    }
    
}

- (void)setUpCrashMonitor {
    TTSDKCrashInstallationConsole *installation = [TTSDKCrashInstallationConsole sharedInstance];
    installation.printAppleFormat = YES;
    
    TTSDKCrashConfiguration *config = [[TTSDKCrashConfiguration alloc] init];
    
    NSError *installError;
    [installation installWithConfiguration:config error:&installError];
    [installation sendAllReportsWithCompletion:^(NSArray<id<TTSDKCrashReport>> * _Nullable filteredReports, NSError * _Nullable error) {
        if (error) {
            [self.logger warn:@"report sent failed: %@", error.description];
        }
        if (filteredReports.count) {
            for (TTSDKCrashReportString *report in filteredReports) {
                if ([report isKindOfClass:[TTSDKCrashReportString class]] == NO) {
                    [self.logger warn:@"Unexpected non-string report: %@", report];
                    continue;
                }
                [self sendCrashReport:report.value];
            }
        }
    }];
}

- (void)sendCrashReport:(NSString *)report {
    if (![TikTokErrorHandler isSDKCrashReport:report]) {
        [self.logger verbose:@"Crash report does not belong to SDK"];
        return;
    }
    NSDictionary *meta = @{
        @"ts": [NSNumber numberWithLongLong:[TikTokErrorHandler getCrashTimetampFromReport:report]],
        @"ex_stack": report,
    };
    NSDictionary *monitorCrashLogProperties = @{
        @"monitor_type": @"exception",
        @"monitor_name": @"exception",
        @"meta": meta
    };
    TikTokAppEvent *monitorCrashLogEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorCrashLogProperties withType:@"monitor"];
    @synchronized(self) {
        [self.eventLogger addEvent:monitorCrashLogEvent];
    }
}

- (void)monitorInitialization:(NSNumber *)initStartTime andEndTime:(NSNumber *)initEndTime
{
    NSDictionary *startMeta = @{
        @"ts": [NSNumber numberWithLongLong:[initStartTime longLongValue]],
    };
    NSDictionary *endMeta = @{
        @"ts": [NSNumber numberWithLongLong:[initEndTime longLongValue]],
        @"latency": [NSNumber numberWithLongLong:[initEndTime longLongValue] - [initStartTime longLongValue]],
    };
    NSDictionary *monitorInitStartProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"init_start",
        @"meta": startMeta
    };
    TikTokAppEvent *monitorInitStart = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorInitStartProperties withType:@"monitor"];
    NSDictionary *monitorInitEndProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"init_end",
        @"meta": endMeta
    };
    TikTokAppEvent *monitorInitEnd = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorInitEndProperties withType:@"monitor"];
    @synchronized(self) {
        [self.eventLogger addEvent:monitorInitStart];
        [self.eventLogger addEvent:monitorInitEnd];
    }
}

// Internally used method for 2D-Retention
- (void)track2DRetention
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *installDate = (NSDate *)[defaults objectForKey:@"tiktokInstallDate"];
    BOOL logged2DRetention = [defaults boolForKey:@"tiktokLogged2DRetention"];
    // Setting this variable to limit recomputations for 2DRetention past second day
    BOOL past2DLimit = [defaults boolForKey:@"tiktokPast2DLimit"];
    if(!past2DLimit) {
        NSDate *currentLaunch = [NSDate date];
        NSDate *oneDayAgo = [currentLaunch dateByAddingTimeInterval:-1 * 24 * 60 * 60];
        NSTimeInterval secondsBetween = [currentLaunch timeIntervalSinceDate:installDate];
        int numberOfDays = secondsBetween / 86400;
        if ([[NSCalendar currentCalendar] isDate:oneDayAgo inSameDayAsDate:installDate] && !logged2DRetention) {
            [self trackEvent:@"2Dretention" withProperties:@{@"type":@"auto"} withId:@""];
            [defaults setBool:YES forKey:@"tiktokLogged2DRetention"];
            [defaults synchronize];
        }
        
        if (numberOfDays > 2) {
            [defaults setBool:YES forKey:@"tiktokPast2DLimit"];
            [defaults synchronize];
        }
    }
}

- (void)trackEvent:(NSString *)eventName
{
    [self trackEvent:eventName withProperties:nil withId:@""];
}

- (void)trackEvent:(NSString *)eventName
    withProperties: (NSDictionary *)properties
            withId: (NSString *)eventId
{
    if(self.SKAdNetworkSupportEnabled) {
        id value = [properties objectForKey:@"value"];
        NSString *valueString;
        if ([value isKindOfClass:[NSString class]]) {
            valueString = value;
        } else if ([value isKindOfClass:[NSNumber class]]) {
            valueString = [value stringValue];
        } else {
            valueString = @"0";
        }
        NSString *currency = [properties objectForKey:@"currency"];
        [[TikTokSKAdNetworkSupport sharedInstance] matchEventToSKANConfig:eventName withValue:valueString currency:TTSafeString(currency)];
    }
    
    TikTokAppEvent *appEvent = [[TikTokAppEvent alloc] initWithEventName:eventName withProperties:properties withEventID:eventId];
    if (self.remoteDebugEnabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *screenshot = [self screenShot];
            appEvent.screenshot = screenshot;
            [self addEvent:appEvent];
        });
    } else {
        [self addEvent:appEvent];
    }
}

- (void)addEvent:(TikTokAppEvent *)appEvent {
    [self.eventLogger addEvent:appEvent];
    if([appEvent.eventName isEqualToString:@"Purchase"]) {
        [self.eventLogger flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
    }
}

- (void)trackEvent:(NSString *)eventName
          withType:(NSString *)type
{
    TikTokAppEvent *appEvent = [[TikTokAppEvent alloc] initWithEventName:eventName withType:type];
    [self addEvent:appEvent];
}

- (void)trackEvent: (NSString *)eventName withId: (NSString *)eventId {
    TikTokAppEvent *appEvent = [[TikTokAppEvent alloc] initWithEventName:eventName];
    appEvent.eventID = eventId;
    [self addEvent:appEvent];
}

- (void)trackTTEvent: (TikTokBaseEvent *)event {
    [self trackEvent:event.eventName withProperties:event.properties withId:event.eventId];
}


- (void)trackEventAndEagerlyFlush:(NSString *)eventName
{
    [self trackEvent:eventName];
    [self.eventLogger flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
}

- (void)trackEventAndEagerlyFlush:(NSString *)eventName
       withProperties: (NSDictionary *)properties
{
    [self trackEvent:eventName withProperties:properties withId:@""];
    [self.eventLogger flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
}

- (void)trackEventAndEagerlyFlush:(NSString *)eventName
       withType:(NSString *)type
{
    [self trackEvent:eventName withType:type];
    [self.eventLogger flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    NSNumber *backgroundMonitorTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    if(self.config.initialFlushDelay && ![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        // pause timer when entering background when first flush has not happened
        [preferences setObject:@"false" forKey:@"AreTimersOn"];
    }
    [preferences setObject:backgroundMonitorTime forKey:@"backgroundMonitorTime"];
    
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // Enabled: Tracking, Auto Logging, 2DRetention Logging
    // Install Date: Available
    // 2D Limit has not been passed
    NSNumber *foregroundMonitorTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *installDate = (NSDate *)[defaults objectForKey:@"tiktokInstallDate"];
    
    [self checkAttStatus];
    
    if ([[defaults objectForKey:@"HasBeenInitialized"] isEqual: @"true"]) {
        [self getGlobalConfig:self.config isFirstInitialization:NO];
    }

    if(self.automaticTrackingEnabled && installDate && self.retentionTrackingEnabled) {
        [self track2DRetention];
    }
    
    if(self.config.initialFlushDelay && ![[defaults objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        // if first flush has not occurred, resume timer without flushing
        [defaults setObject:@"true" forKey:@"AreTimersOn"];
        [defaults synchronize];
    } else {
        // else flush when entering foreground
        [self.eventLogger flush:TikTokAppEventsFlushReasonAppBecameActive];
    }
    
    if([defaults objectForKey:@"backgroundMonitorTime"] != nil) {
        NSNumber *backgroundMonitorTime = [defaults objectForKey:@"backgroundMonitorTime"];
        NSNumber *lastForegroundMonitorTime = [defaults objectForKey:@"foregroundMonitorTime"];
        NSDictionary *meta = @{
            @"ts": foregroundMonitorTime,
            @"latency": [NSNumber numberWithLongLong:[backgroundMonitorTime longLongValue] - [lastForegroundMonitorTime longLongValue]],
        };
        NSDictionary *monitorForegroundProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"foreground",
            @"meta": meta
        };
        NSDictionary *backgroundMeta = @{
            @"ts": backgroundMonitorTime,
            @"latency": [NSNumber numberWithLongLong:[foregroundMonitorTime longLongValue] - [backgroundMonitorTime longLongValue]],
        };
        NSDictionary *monitorBackgroundProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"background",
            @"meta": backgroundMeta
        };
        TikTokAppEvent *monitorForegroundEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorForegroundProperties withType:@"monitor"];
        TikTokAppEvent *monitorBackgroundEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorBackgroundProperties withType:@"monitor"];
        
        @synchronized (self) {
            [self.eventLogger addEvent:monitorForegroundEvent];
            [self.eventLogger addEvent:monitorBackgroundEvent];
        }
        
        if ([TikTokEDPConfig sharedConfig].enable_sdk && [TikTokEDPConfig sharedConfig].enable_from_ttconfig && [TikTokEDPConfig sharedConfig].enable_page_show_track) {
            // Report when coming back from background.
            NSInteger pageDepth = 0;
            UIWindow *window = [[UIApplication sharedApplication] keyWindow];
            NSDictionary *viewTree = [TikTokViewUtility digView:window.rootViewController.view atDepth:0 maxDepth:&pageDepth];
            NSDictionary *pageShowProperties = @{
                @"current_page_name": NSStringFromClass([self class]),
                @"index": @(pageIndex),
                @"from_background": @(YES),
                @"page_components": viewTree,
                @"page_deep_count": @([TikTokViewUtility maxDepthOfSubviews:window.rootViewController.view]),
                @"monitor_type": @"enhanced_data_postback"
            };
            [TikTokBusiness trackEvent:@"page_show" withProperties:pageShowProperties];
        }
        
    }
    [defaults setObject:foregroundMonitorTime forKey:@"foregroundMonitorTime"];
    [defaults removeObjectForKey:@"backgroundMonitorTime"];
    [defaults synchronize];
}

- (nullable NSString *)idfa
{
    return [[TikTokDeviceInfo alloc] deviceIdForAdvertisers];
}

- (BOOL)appInForeground
{
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)appInBackground
{
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)appIsInactive
{
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        return YES;
    } else {
        return NO;
    }
}

- (void)setTrackingEnabled:(BOOL)trackingEnabled
{
    _trackingEnabled = trackingEnabled;
}

- (void)setCustomUserAgent:(NSString *)customUserAgent
{
    [[TikTokUserAgentCollector singleton] setCustomUserAgent:customUserAgent];
}

- (void)updateAccessToken:(nonnull NSString *)accessToken
{
    self.accessToken = accessToken;
    if(!self.isGlobalConfigFetched) {
        [self getGlobalConfig:self.config isFirstInitialization:NO];
    }
}

- (void)identifyWithExternalID:(nullable NSString *)externalID
              externalUserName:(nullable NSString *)externalUserName
                   phoneNumber:(nullable NSString *)phoneNumber
                         email:(nullable NSString *)email
{
    NSNumber *identifyMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    
    if([TikTokIdentifyUtility sharedInstance].isIdentified) {
        [self.logger warn:@"TikTok SDK has already identified. If you want to switch to another user, please call the function TikTokBusinessSDK.logout()"];
        return;
    }
    
    [[TikTokIdentifyUtility sharedInstance] setUserInfoWithExternalID:externalID externalUserName:externalUserName phoneNumber:phoneNumber email:email origin:NSStringFromClass([self class])];
    [self trackEventAndEagerlyFlush:@"Identify" withType: @"identify"];
    NSNumber *identifyMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSDictionary *meta = @{
        @"ts": identifyMonitorStartTime,
        @"latency": [NSNumber numberWithLongLong:[identifyMonitorEndTime longLongValue] - [identifyMonitorStartTime longLongValue]],
        @"email": @(TTCheckValidString(email)),
        @"phone": @(TTCheckValidString(phoneNumber)),
        @"extid": @(TTCheckValidString(externalID)),
        @"username": @(TTCheckValidString(externalUserName))
    };
    NSDictionary *monitorIdentifyProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"identify",
        @"meta": meta
    };
    TikTokAppEvent *monitorIdentifyEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorIdentifyProperties withType:@"monitor"];
    @synchronized(self) {
        [self.eventLogger addEvent:monitorIdentifyEvent];
    }
}

- (void)logout
{
    NSNumber *logoutMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    
    // clear old anonymousID and userInfo from NSUserDefaults
    [[TikTokIdentifyUtility sharedInstance] resetUserInfo];
       
    NSString *anonymousID = [[TikTokIdentifyUtility sharedInstance] getOrGenerateAnonymousID];
    [[TikTokBusiness getInstance] setAnonymousID:anonymousID];
    [self.logger verbose:@"AnonymousID on logout: %@", self.anonymousID];
    [self.eventLogger flush:TikTokAppEventsFlushReasonLogout];
    NSNumber *logoutMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSDictionary *meta = @{
        @"ts": logoutMonitorStartTime,
        @"latency": [NSNumber numberWithLongLong:[logoutMonitorEndTime longLongValue] - [logoutMonitorStartTime longLongValue]],
    };
    NSDictionary *monitorIdentifyProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"logout",
        @"meta": meta
    };
    TikTokAppEvent *monitorIdentifyEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorIdentifyProperties withType:@"monitor"];
    @synchronized (self) {
        [self.eventLogger addEvent:monitorIdentifyEvent];
    }
}

- (void)explicitlyFlush
{
    [self.eventLogger flush:TikTokAppEventsFlushReasonExplicitlyFlush];
}

- (BOOL)isTrackingEnabled
{
    return self.trackingEnabled;
}

- (BOOL)isUserTrackingEnabled
{
    return self.userTrackingEnabled;
}

- (BOOL)isInitialized {
    return self.initialized;
}

- (void)getGlobalConfig:(TikTokConfig *)tiktokConfig
  isFirstInitialization: (BOOL)isFirstInitialization
{
    [self.requestHandler getRemoteSwitch:tiktokConfig withCompletionHandler:^(BOOL isRemoteSwitchOn, NSDictionary *globalConfig) {
        self.isRemoteSwitchOn = isRemoteSwitchOn;
        self.isGlobalConfigFetched = TTCheckValidDictionary(globalConfig);
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        if(!self.isRemoteSwitchOn) {
            [self.logger info:@"Remote switch is off"];
            [defaults setObject:@"false" forKey:@"AreTimersOn"];
            [defaults synchronize];
            return;
        }
        [self loadUserAgent];
        [self.logger info:@"Remote switch is on"];
        
        // restart timers if they are off
        if ([[defaults objectForKey:@"AreTimersOn"]  isEqual: @"false"]) {
            [defaults setObject:@"true" forKey:@"AreTimersOn"];
            [defaults synchronize];
        }
        if (self.isGlobalConfigFetched) {
            self.remoteDebugEnabled = [[globalConfig objectForKey:@"enable_debug_mode"] boolValue];
            NSNumber *exchangeErrReportRate = [globalConfig objectForKey:@"skan4_exchange_err_report_rate"];
            if (TTCheckValidNumber(exchangeErrReportRate)) {
                self.exchangeErrReportRate = [exchangeErrReportRate doubleValue];
            }
            self.exchangeErrReportRate = 1;
            if (self.SKAdNetworkSupportEnabled) {
                NSInteger currentWindow = [[TikTokSKAdNetworkSupport sharedInstance] getConversionWindowForTimestamp:[TikTokAppEventUtility getCurrentTimestamp]];
                if ([[defaults objectForKey:TTSKANTimeWindowKey] integerValue] != currentWindow) {
                    [defaults setObject:@(currentWindow) forKey:TTSKANTimeWindowKey];
                    [defaults removeObjectForKey:TTLatestFineValueKey];
                    [defaults removeObjectForKey:TTLatestCoarseValueKey];
                    [defaults removeObjectForKey:TTAccumulatedSKANValuesKey];
                    [defaults synchronize];
                    [[TikTokSKANEventPersistence persistence] clearEvents];
                }
                // match historical events and flag "matched"
                for (TikTokSKAdNetworkWindow *window in [TikTokSKAdNetworkConversionConfiguration sharedInstance].conversionValueWindows) {
                    if (window.postbackIndex == currentWindow) {
                        [[TikTokSKAdNetworkSupport sharedInstance] matchPersistedSKANEventsInWindow:window];
                        break;
                    }
                }
                
            }
            
            NSDictionary *EDPConfigDict = [globalConfig objectForKey:@"enhanced_data_postback_native_config"];
            [TikTokEDPConfig sharedConfig].enable_from_ttconfig = tiktokConfig.autoEDPEventEnabled;
            if (TTCheckValidDictionary(EDPConfigDict)) {
                [[TikTokEDPConfig sharedConfig] configWithDict:EDPConfigDict];
                
                NSString *sourceURLString = [defaults objectForKey:@"source_url"];
                NSString *referString = [defaults objectForKey:@"refer"];
                if ((TTCheckValidString(referString) || isFirstInitialization) && [TikTokEDPConfig sharedConfig].enable_sdk && [TikTokEDPConfig sharedConfig].enable_from_ttconfig && [TikTokEDPConfig sharedConfig].enable_app_launch_track) {
                    NSDictionary *launchOptionProperties = @{
                        @"source_url": TTSafeString(sourceURLString),
                        @"refer": TTSafeString(referString),
                        @"monitor_type": @"enhanced_data_postback"
                    };
                    [TikTokBusiness trackEvent:@"app_launch" withProperties:launchOptionProperties];
                }
            }
         }
        
        // if SDK has not been initialized, we initialize it
        if(isFirstInitialization || ![[defaults objectForKey:@"HasBeenInitialized"]  isEqual: @"true"]) {
            BOOL crashMonitorEnabled = [[globalConfig objectForKey:@"crash_monitor_enable"] boolValue];
            if (crashMonitorEnabled) {
                [self setUpCrashMonitor];
            }
            
            [self.logger info:@"TikTok SDK Initialized Successfully!"];
            [defaults setObject:@"true" forKey:@"HasBeenInitialized"];
            [defaults setObject:@([TikTokAppEventUtility getCurrentTimestamp]) forKey:TTUserDefaultsKey_firstLaunchTime];
            [defaults synchronize];
            BOOL launchedBefore = [defaults boolForKey:@"tiktokLaunchedBefore"];
            NSDate *installDate = (NSDate *)[defaults objectForKey:@"tiktokInstallDate"];
            
            // SKAdNetwork 3.0 Support (works on iOS 14.0+)
            if(self.SKAdNetworkSupportEnabled) {
                [[TikTokSKAdNetworkSupport sharedInstance] registerAppForAdNetworkAttribution];
            }
            
            BOOL globalConfigRetentionTrackingEnabled = [globalConfig objectForKey:@"auto_track_Retention_enable"]!=nil ? [[globalConfig objectForKey:@"auto_track_Retention_enable"] boolValue] : YES;
            self.retentionTrackingEnabled = self.retentionTrackingEnabled && globalConfigRetentionTrackingEnabled;
            BOOL globalConfigPaymentTrackingEnabled = [globalConfig objectForKey:@"auto_track_Payment_enable"]!=nil ? [[globalConfig objectForKey:@"auto_track_Payment_enable"] boolValue] : YES;
            self.paymentTrackingEnabled = self.paymentTrackingEnabled && globalConfigPaymentTrackingEnabled;
            // Enabled: Tracking, Auto Tracking, Install Tracking
            // Launched Before: False
            if(self.automaticTrackingEnabled && !launchedBefore){
                
                if (self.installTrackingEnabled) {
                    [self trackEvent:@"InstallApp" withProperties:@{@"type":@"auto"} withId:@""];
                    if (self.isGlobalConfigFetched) {
                        [defaults setBool:YES forKey:@"tiktokMatchedInstall"];
                    }
                }
                NSDate *currentLaunch = [NSDate date];
                [defaults setBool:YES forKey:@"tiktokLaunchedBefore"];
                [defaults setObject:currentLaunch forKey:@"tiktokInstallDate"];
                [defaults synchronize];
            }

            // Enabled: Tracking, Auto Tracking, Launch Logging
            if(self.automaticTrackingEnabled && self.launchTrackingEnabled){
                [self trackEvent:@"LaunchAPP" withProperties:@{@"type":@"auto"} withId:@""];
            }

            // Enabled: Auto Tracking, 2DRetention Tracking
            // Install Date: Available
            // 2D Limit has not been passed
            if(self.automaticTrackingEnabled && installDate && self.retentionTrackingEnabled) {
                [self track2DRetention];
            }

            if(self.automaticTrackingEnabled && self.paymentTrackingEnabled) {
                [TikTokPaymentObserver startObservingTransactions];
            } else {
                [TikTokPaymentObserver stopObservingTransactions];
            }
            
            NSNumber *initStartTimestamp = [defaults objectForKey:@"monitorInitStartTime"];
            NSNumber *initEndTimestamp = [TikTokAppEventUtility getCurrentTimestampAsNumber];
            [self monitorInitialization:initStartTimestamp andEndTime:initEndTimestamp];
        }
        if (self.isGlobalConfigFetched && self.automaticTrackingEnabled && self.installTrackingEnabled) {
            BOOL matchedInstall = [defaults boolForKey:@"tiktokMatchedInstall"];
            if (!matchedInstall) {
                [[TikTokSKAdNetworkSupport sharedInstance] matchEventToSKANConfig:@"InstallApp" withValue:@"0" currency:@""];
                [defaults setBool:YES forKey:@"tiktokMatchedInstall"];
                [defaults synchronize];
            }
        }
    }];
}

- (void)loadUserAgent {
    NSNumber *userAgentMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    dispatch_async(self.isolationQueue, ^(){
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [[TikTokUserAgentCollector singleton] loadUserAgentWithCompletion:^(NSString * _Nullable userAgent) {
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    });
    NSNumber *userAgentMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSDictionary *userAgentStartMeta = @{
        @"ts": userAgentMonitorStartTime,
    };
    NSDictionary *monitorUserAgentStartProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"ua_init",
        @"meta": userAgentStartMeta
    };
    NSDictionary *userAgentEndMeta = @{
        @"ts": userAgentMonitorEndTime,
        @"latency": [NSNumber numberWithLongLong:[userAgentMonitorEndTime longLongValue] - [userAgentMonitorStartTime longLongValue]],
        @"success": [NSNumber numberWithBool:true],
    };
    NSDictionary *monitorUserAgentEndProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"ua_end",
        @"meta": userAgentEndMeta
    };
    TikTokAppEvent *monitorUserAgentStartEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
    TikTokAppEvent *monitorUserAgentEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentEndProperties withType:@"monitor"];
    @synchronized(self) {
        [self.eventLogger addEvent:monitorUserAgentStartEvent];
        [self.eventLogger addEvent:monitorUserAgentEndEvent];
    }
}

- (void)checkAttStatus {
    if (@available(iOS 14, *)) {
        if(ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
            self.userTrackingEnabled = YES;
            [self.logger info:@"Tracking is enabled"];
        } else {
            self.userTrackingEnabled = NO;
            [self.logger info:@"Tracking is disabled"];
        }
    } else {
        // For previous versions, we can assume that IDFA can be collected
        self.userTrackingEnabled = YES;
    }
}

- (void)fetchDeferredDeeplinkWithCompletion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion {
    if (!completion) {
        return;
    }
    if (!self.initialized) {
        NSError *error = [NSError errorWithDomain:@"com.TikTokBusinessSDK.error"
                                             code:-1
                                         userInfo:@{
            NSLocalizedDescriptionKey : @"SDK not initialized",
        }];
        completion(nil, error);
        return;
    }
    [self.requestHandler fetchDeferredDeeplinkWithConfig:self.config completion:^(NSURL * _Nullable url, NSError * _Nullable error) {
        completion(url, error);
    }];
}


+(void)produceFatalError
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] produceFatalError];
    }
}

-(void)produceFatalError
{
    
    @throw([NSException exceptionWithName:@"TikTokBusinessSDK" reason:@"This is a test error!" userInfo:nil]);
}

- (NSString *)generateTestEventCodeWithConfig:(TikTokConfig *)config
{
    if (!self.isDebugMode
        || (!config.tiktokAppId)) {
        return nil;
    }
    
    NSString *processedString = [config.tiktokAppId stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSArray<NSString *> *components = [processedString componentsSeparatedByString:@","];
    for (NSString *component in components) {
        if (TTCheckValidString(component)) {
            return component;
        }
    }
    
    return TTSafeString(config.tiktokAppId);
}

+ (NSString *)getSDKVersion
{
    return SDK_VERSION;
}

- (NSString *)screenShot {
    NSData *imageData = nil;
    CGRect rect = [UIScreen mainScreen].bounds;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
    [window drawViewHierarchyInRect:rect afterScreenUpdates:NO];
    UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    // compress
    imageData = UIImageJPEGRepresentation(snapshotImage, 0.5);
    NSString *dataStr = [imageData base64EncodedStringWithOptions:0];
    return dataStr;
}

@end
