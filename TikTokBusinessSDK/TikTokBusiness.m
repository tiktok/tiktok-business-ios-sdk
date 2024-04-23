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
#import "TikTokConfig.h"
#import "TikTokLogger.h"
#import "AppEvents/TikTokAppEvent.h"
#import "AppEvents/TikTokAppEventQueue.h"
#import "AppEvents/TikTokAppEventStore.h"
#import "TikTokPaymentObserver.h"
#import "TikTokFactory.h"
#import "TikTokErrorHandler.h"
#import "TikTokIdentifyUtility.h"
#import "TikTokUserAgentCollector.h"
#import "TikTokSKAdNetworkSupport.h"
#import "UIDevice+TikTokAdditions.h"
#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokBusinessSDKMacros.h"

@interface TikTokBusiness()

@property (nonatomic, weak) id<TikTokLogger> logger;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL trackingEnabled;
@property (nonatomic) BOOL automaticTrackingEnabled;
@property (nonatomic) BOOL installTrackingEnabled;
@property (nonatomic) BOOL launchTrackingEnabled;
@property (nonatomic) BOOL retentionTrackingEnabled;
@property (nonatomic) BOOL paymentTrackingEnabled;
@property (nonatomic) BOOL appTrackingDialogSuppressed;
@property (nonatomic) BOOL SKAdNetworkSupportEnabled;
@property (nonatomic) BOOL isGlobalConfigFetched;
@property (nonatomic, strong, nullable) TikTokAppEventQueue *queue;
@property (nonatomic, strong, nullable) TikTokRequestHandler *requestHandler;
@property (nonatomic, strong, readwrite) dispatch_queue_t isolationQueue;
@property (nonatomic, assign, readwrite) BOOL isDebugMode;
@property (nonatomic, copy) NSString *testEventCode;
@property (nonatomic, assign, readwrite) BOOL isLDUMode;

@end


@implementation TikTokBusiness: NSObject

#pragma mark - Object Lifecycle Methods

static TikTokBusiness * defaultInstance = nil;
static dispatch_once_t onceToken = 0;

+ (id)getInstance
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

- (id)init
{
    self = [super init];
    if(self == nil) {
        return nil;
    }
    
    self.isolationQueue = dispatch_queue_create([@"tiktokIsolationQueue" UTF8String], DISPATCH_QUEUE_SERIAL);
    self.queue = nil;
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

    return self;
}

#pragma mark - Public static methods

+ (void)initializeSdk:(TikTokConfig *)tiktokConfig
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] initializeSdk: tiktokConfig];
    }
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
        [[TikTokBusiness getInstance] trackEvent:eventName withProperties:properties];
    }
}

+ (void)trackEvent:(NSString *)eventName
withType:(NSString *)type
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] trackEvent:eventName withType:type];
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
             phoneNumber:(nullable NSString *)phoneNumber
                       email:(nullable NSString *)email
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] identifyWithExternalID:externalID phoneNumber:phoneNumber email:email];
        
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

+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^_Nullable)(NSUInteger status))completion
{
    @synchronized (self) {
        [[TikTokBusiness getInstance] requestTrackingAuthorizationWithCompletionHandler:completion];
    }
}

+ (TikTokAppEventQueue *)getQueue
{
    @synchronized (self) {
        return [[TikTokBusiness getInstance] queue];
    }
}

+ (long)getInMemoryEventCount
{
    @synchronized (self) {
        return [[[TikTokBusiness getInstance] queue] eventQueue].count;
    }
}

+ (long)getInDiskEventCount
{
    @synchronized (self) {
        return [TikTokAppEventStore retrievePersistedAppEvents].count;
    }
}

+ (long)getTimeInSecondsUntilFlush
{
    @synchronized (self) {
        return [[[TikTokBusiness getInstance] queue] timeInSecondsUntilFlush];
    }
}

+ (long)getRemainingEventsUntilFlushThreshold
{
    @synchronized (self) {
        return [[[TikTokBusiness getInstance] queue] remainingEventsUntilFlushThreshold];
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

- (void)initializeSdk:(TikTokConfig *)tiktokConfig
{
    if (self.queue != nil) {
        [self.logger warn:@"TikTok SDK has been initialized already!"];
        return;
    }
    NSNumber *initStartTimestamp = [TikTokAppEventUtility getCurrentTimestampAsNumber];

    NSSetUncaughtExceptionHandler(handleUncaughtExceptionPointer);
    self.trackingEnabled = tiktokConfig.trackingEnabled;
    self.automaticTrackingEnabled = tiktokConfig.automaticTrackingEnabled;
    self.installTrackingEnabled = tiktokConfig.installTrackingEnabled;
    self.launchTrackingEnabled = tiktokConfig.launchTrackingEnabled;
    self.retentionTrackingEnabled = tiktokConfig.retentionTrackingEnabled;
    self.paymentTrackingEnabled = tiktokConfig.paymentTrackingEnabled;
    self.appTrackingDialogSuppressed = tiktokConfig.appTrackingDialogSuppressed;
    self.SKAdNetworkSupportEnabled = tiktokConfig.SKAdNetworkSupportEnabled;
    self.accessToken = tiktokConfig.accessToken;
    NSString *anonymousID = [TikTokIdentifyUtility getOrGenerateAnonymousID];
    self.anonymousID = anonymousID;
    self.isDebugMode = tiktokConfig.debugModeEnabled;
    self.testEventCode = self.isDebugMode ? [self generateTestEventCodeWithConfig:tiktokConfig] : nil;
    self.isLDUMode = tiktokConfig.LDUModeEnabled;
    
    [self loadUserAgent];

    self.requestHandler = [TikTokFactory getRequestHandler];
    self.queue = [[TikTokAppEventQueue alloc] initWithConfig:tiktokConfig];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"true" forKey:@"AreTimersOn"];
//    [defaults setObject:@"monitorInitStartTime" forKey:@"monitorInitStartTime"];
    
    [self getGlobalConfig:tiktokConfig isFirstInitialization:YES];
    
    /* Monitor Init Start */
    /* ------------------ */
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

    [self sendCrashReportWithConfig: tiktokConfig];
    NSNumber *initEndTimestamp = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    [self monitorInitialization:initStartTimestamp andEndTime:initEndTimestamp];
}

- (void)monitorInitialization:(NSNumber *)initStartTime andEndTime:(NSNumber *)initEndTime
{
    NSDictionary *startMeta = @{
        @"ts": initStartTime,
    };
    NSDictionary *endMeta = @{
        @"ts": initEndTime,
        @"latency": [NSNumber numberWithDouble:[initEndTime floatValue] - [initEndTime floatValue]],
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
    NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
    [appEventsToBeFlushed addObject:monitorInitStart];
    [appEventsToBeFlushed addObject:monitorInitEnd];
    @synchronized(self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
        });
    }
}

- (void)sendCrashReportWithConfig:(TikTokConfig *)config
{
    NSDictionary<NSString *, id> *crashLog = [TikTokErrorHandler getLastestCrashLog];
    
    NSLog(@"crashLog: %@", crashLog);
    
    if (crashLog != nil) {
//        [self.requestHandler sendCrashReport:crashLog withConfig:config withCompletionHandler: ^(void){
//            [TikTokErrorHandler clearCrashReportFiles];
//        }];
        NSDictionary *meta = @{
            @"ts": [NSNumber numberWithInt:[[crashLog objectForKey:@"timestamp"] intValue]],
            @"ex_stack": [crashLog objectForKey:@"crash_info"],
        };
        NSDictionary *monitorCrashLogProperties = @{
            @"monitor_type": @"exception",
            @"monitor_name": @"exception",
            @"meta": meta
        };
        TikTokAppEvent *monitorCrashLogEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorCrashLogProperties withType:@"monitor"];
        NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
        [appEventsToBeFlushed addObject:monitorCrashLogEvent];
        @synchronized(self) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
                [TikTokErrorHandler clearCrashReportFiles];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
            });
        }
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
            [self trackEvent:@"2Dretention"];
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
    TikTokAppEvent *appEvent = [[TikTokAppEvent alloc] initWithEventName:eventName];
    if(self.SKAdNetworkSupportEnabled) {
        [[TikTokSKAdNetworkSupport sharedInstance] matchEventToSKANConfig:eventName withValue:@"0"];
    }
    [self.queue addEvent:appEvent];
    if([eventName isEqualToString:@"Purchase"]) {
        [self.queue flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
    }
}

- (void)trackEvent:(NSString *)eventName
    withProperties: (NSDictionary *)properties
{
    TikTokAppEvent *appEvent = [[TikTokAppEvent alloc] initWithEventName:eventName withProperties:properties];
     
    if(self.SKAdNetworkSupportEnabled) {
        NSString *value = [properties objectForKey:@"value"];
        [[TikTokSKAdNetworkSupport sharedInstance] matchEventToSKANConfig:eventName withValue:value];
    }
    [self.queue addEvent:appEvent];
    if([eventName isEqualToString:@"Purchase"]) {
        [self.queue flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
    }
}

- (void)trackEvent:(NSString *)eventName
          withType:(NSString *)type
{
    TikTokAppEvent *appEvent = [[TikTokAppEvent alloc] initWithEventName:eventName withType:type];
    [self.queue addEvent:appEvent];
    if([eventName isEqualToString:@"Purchase"]) {
        [self.queue flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
    }
}


- (void)trackEventAndEagerlyFlush:(NSString *)eventName
{
    [self trackEvent:eventName];
    [self.queue flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
}

- (void)trackEventAndEagerlyFlush:(NSString *)eventName
       withProperties: (NSDictionary *)properties
{
    [self trackEvent:eventName withProperties:properties];
    [self.queue flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
}

- (void)trackEventAndEagerlyFlush:(NSString *)eventName
       withType:(NSString *)type
{
    [self trackEvent:eventName withType:type];
    [self.queue flush:TikTokAppEventsFlushReasonEagerlyFlushingEvent];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    NSNumber *backgroundMonitorTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    [TikTokAppEventStore persistAppEvents:self.queue.eventQueue];
    [self.queue.eventQueue removeAllObjects];
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    if(self.queue.config.initialFlushDelay && ![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
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

    if(self.automaticTrackingEnabled && installDate && self.retentionTrackingEnabled) {
        [self track2DRetention];
    }
    
    if ([[defaults objectForKey:@"HasBeenInitialized"]  isEqual: @"true"]) {
        [self getGlobalConfig:self.queue.config isFirstInitialization:NO];
    }
    
    if(self.queue.config.initialFlushDelay && ![[defaults objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        // if first flush has not occurred, resume timer without flushing
        [defaults setObject:@"true" forKey:@"AreTimersOn"];
    } else {
        // else flush when entering foreground
        [self.queue flush:TikTokAppEventsFlushReasonAppBecameActive];
    }
    
    if([defaults objectForKey:@"backgroundMonitorTime"] != nil) {
        NSNumber *backgroundMonitorTime = [defaults objectForKey:@"backgroundMonitorTime"];
        NSNumber *lastForegroundMonitorTime = [defaults objectForKey:@"foregroundMonitorTime"];
        NSDictionary *meta = @{
            @"ts": foregroundMonitorTime,
            @"latency": [NSNumber numberWithInt:[backgroundMonitorTime intValue] - [lastForegroundMonitorTime intValue]],
        };
        NSDictionary *monitorForegroundProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"foreground",
            @"meta": meta
        };
        NSDictionary *backgroundMeta = @{
            @"ts": backgroundMonitorTime,
            @"latency": [NSNumber numberWithInt:[foregroundMonitorTime intValue] - [backgroundMonitorTime intValue]],
        };
        NSDictionary *monitorBackgroundProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"background",
            @"meta": backgroundMeta
        };
        TikTokAppEvent *monitorForegroundEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorForegroundProperties withType:@"monitor"];
        TikTokAppEvent *monitorBackgroundEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorBackgroundProperties withType:@"monitor"];
        [self.queue addEvent:monitorForegroundEvent];
        [self.queue addEvent:monitorBackgroundEvent];
    }
    [defaults setObject:foregroundMonitorTime forKey:@"foregroundMonitorTime"];
    [defaults removeObjectForKey:@"backgroundMonitorTime"];
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
    if(trackingEnabled) {
        [TikTokPaymentObserver startObservingTransactions];
    } else {
        [TikTokPaymentObserver stopObservingTransactions];
    }
}

- (void)setCustomUserAgent:(NSString *)customUserAgent
{
    [[TikTokUserAgentCollector singleton] setUserAgent:customUserAgent];
}

- (void)updateAccessToken:(nonnull NSString *)accessToken
{
    self.accessToken = accessToken;
    if(!self.isGlobalConfigFetched) {
        [self getGlobalConfig:self.queue.config isFirstInitialization:NO];
    }
}

- (void)identifyWithExternalID:(nullable NSString *)externalID
             phoneNumber:(nullable NSString *)phoneNumber
                       email:(nullable NSString *)email
{
    NSNumber *identifyMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if([[defaults objectForKey:@"IsIdentified"]  isEqual: @"true"]){
        [self.logger warn:@"TikTok SDK has already identified. If you want to switch to another user, please call the function TikTokBusinessSDK.logout()"];
        return;
    }
    
    [TikTokIdentifyUtility setUserInfoDefaultsWithExternalID:externalID phoneNumber:phoneNumber email:email origin:NSStringFromClass([self class])];
    [self trackEventAndEagerlyFlush:@"Identify" withType: @"identify"];
    NSNumber *identifyMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSDictionary *meta = @{
        @"ts": identifyMonitorStartTime,
        @"latency": [NSNumber numberWithInt:[identifyMonitorEndTime intValue] - [identifyMonitorStartTime intValue]],
        @"email": email == nil ? [NSNumber numberWithBool:false] : [NSNumber numberWithBool:true],
        @"phone": phoneNumber == nil ? [NSNumber numberWithBool:false] : [NSNumber numberWithBool:true],
        @"extid": externalID == nil ? [NSNumber numberWithBool:false] : [NSNumber numberWithBool:true],
    };
    NSDictionary *monitorIdentifyProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"identify",
        @"meta": meta
    };
    TikTokAppEvent *monitorIdentifyEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorIdentifyProperties withType:@"monitor"];
    [self.queue addEvent:monitorIdentifyEvent];
}

- (void)logout
{
    NSNumber *logoutMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    
    // clear old anonymousID and userInfo from NSUserDefaults
    [TikTokIdentifyUtility resetNSUserDefaults];
       
    NSString *anonymousID = [TikTokIdentifyUtility getOrGenerateAnonymousID];
    [[TikTokBusiness getInstance] setAnonymousID:anonymousID];
    [self.logger verbose:@"AnonymousID on logout: %@", self.anonymousID];
    [self.queue flush:TikTokAppEventsFlushReasonLogout];
    NSNumber *logoutMonitorEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    NSDictionary *meta = @{
        @"ts": logoutMonitorStartTime,
        @"latency": [NSNumber numberWithInt:[logoutMonitorEndTime intValue] - [logoutMonitorStartTime intValue]],
    };
    NSDictionary *monitorIdentifyProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"logout",
        @"meta": meta
    };
    TikTokAppEvent *monitorIdentifyEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorIdentifyProperties withType:@"monitor"];
    [self.queue addEvent:monitorIdentifyEvent];
    
}

- (void)explicitlyFlush
{
    [self.queue flush:TikTokAppEventsFlushReasonExplicitlyFlush];
}

- (BOOL)isTrackingEnabled
{
    return self.trackingEnabled;
}

- (BOOL)isUserTrackingEnabled
{
    return self.userTrackingEnabled;
}

- (void)getGlobalConfig:(TikTokConfig *)tiktokConfig
  isFirstInitialization: (BOOL)isFirstInitialization
{
    NSNumber *configMonitorStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    [self.requestHandler getRemoteSwitch:tiktokConfig withCompletionHandler:^(BOOL isRemoteSwitchOn, BOOL isGlobalConfigFetched) {
        self.isRemoteSwitchOn = isRemoteSwitchOn;
        self.isGlobalConfigFetched = isGlobalConfigFetched;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        if(!self.isRemoteSwitchOn) {
            [self.logger info:@"Remote switch is off"];
            [defaults setObject:@"false" forKey:@"AreTimersOn"];
            self.queue.timeInSecondsUntilFlush = 0;
            return;
        }
        
        [self.logger info:@"Remote switch is on"];
        
        // restart timers if they are off
        if ([[defaults objectForKey:@"AreTimersOn"]  isEqual: @"false"]) {
            [defaults setObject:@"true" forKey:@"AreTimersOn"];
        }
        
        // if SDK has not been initialized, we initialize it
        if(isFirstInitialization || ![[defaults objectForKey:@"HasBeenInitialized"]  isEqual: @"true"]) {

            [self.logger info:@"TikTok SDK Initialized Successfully!"];
            [defaults setObject:@"true" forKey:@"HasBeenInitialized"];
            BOOL launchedBefore = [defaults boolForKey:@"tiktokLaunchedBefore"];
            NSDate *installDate = (NSDate *)[defaults objectForKey:@"tiktokInstallDate"];

            // Enabled: Tracking, Auto Tracking, Install Tracking
            // Launched Before: False
            if(self.automaticTrackingEnabled && !launchedBefore && self.installTrackingEnabled){
                [self trackEvent:@"InstallApp"];
                // SKAdNetwork Support for Install Tracking (works on iOS 14.0+)
                if(self.SKAdNetworkSupportEnabled) {
                    [[TikTokSKAdNetworkSupport sharedInstance] registerAppForAdNetworkAttribution];
                }
                NSDate *currentLaunch = [NSDate date];
                [defaults setBool:YES forKey:@"tiktokLaunchedBefore"];
                [defaults setObject:currentLaunch forKey:@"tiktokInstallDate"];
                [defaults synchronize];
            }

            // Enabled: Tracking, Auto Tracking, Launch Logging
            if(self.automaticTrackingEnabled && self.launchTrackingEnabled){
                [self trackEvent:@"LaunchAPP"];
            }

            // Enabled: Auto Tracking, 2DRetention Tracking
            // Install Date: Available
            // 2D Limit has not been passed
            if(self.automaticTrackingEnabled && installDate && self.retentionTrackingEnabled){
                [self track2DRetention];
            }

            if(self.automaticTrackingEnabled && self.paymentTrackingEnabled){
                [TikTokPaymentObserver startObservingTransactions];
            }

            if(!self.automaticTrackingEnabled){
                [TikTokPaymentObserver stopObservingTransactions];
            }

            // Remove this later, based on where modal needs to be called to start tracking
            // This will be needed to be called before we can call a function to get IDFA
            if(!self.appTrackingDialogSuppressed) {
                [self requestTrackingAuthorizationWithCompletionHandler:^(NSUInteger status) {}];
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
        @"latency": [NSNumber numberWithInt:[userAgentMonitorEndTime intValue] - [userAgentMonitorStartTime intValue]],
        @"success": [NSNumber numberWithBool:true],
    };
    NSDictionary *monitorUserAgentEndProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"ua_end",
        @"meta": userAgentEndMeta
    };
    TikTokAppEvent *monitorUserAgentStartEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentStartProperties withType:@"monitor"];
    TikTokAppEvent *monitorUserAgentEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorUserAgentEndProperties withType:@"monitor"];
    NSMutableArray *appEventsToBeFlushed = [[NSMutableArray alloc] init];
    [appEventsToBeFlushed addObject:monitorUserAgentStartEvent];
    [appEventsToBeFlushed addObject:monitorUserAgentEndEvent];
    @synchronized(self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TikTokAppEventStore persistAppEvents:appEventsToBeFlushed];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
        });
    }
}

- (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(NSUInteger))completion
{
    [UIDevice.currentDevice requestTrackingAuthorizationWithCompletionHandler:^(NSUInteger status)
    {
        if (completion) {
            completion(status);
            if (@available(iOS 14, *)) {
                if(status == ATTrackingManagerAuthorizationStatusAuthorized) {
                    self.userTrackingEnabled = YES;
                    [self.logger info:@"Tracking is enabled"];
                } else {
                    self.userTrackingEnabled = NO;
                    [self.logger info:@"Tracking is disabled"];
                }
            } else {
                // Fallback on earlier versions
            }
        }
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
    
    return [config.tiktokAppId stringValue];
}

@end
