//
//  TikTokEventLogger.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/10/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokEventLogger.h"
#import "TikTokAppEventUtility.h"
#import "TikTokBusiness.h"
#import "TikTokConfig.h"
#import "TikTokLogger.h"
#import "TikTokFactory.h"
#import "TikTokErrorHandler.h"
#import "TikTokTypeUtility.h"
#import "TikTokBaseEventPersistence.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

#define EVENT_FLUSH_LIMIT 100
#define API_LIMIT 50
#define FLUSH_PERIOD_IN_SECONDS 15

@interface TikTokEventLogger()

@property (nonatomic, strong) TikTokLogger *logger;
@property (nonatomic, strong, nullable) TikTokRequestHandler *requestHandler;
@property (nonatomic, strong) dispatch_queue_t loggerQueue;

@end

@implementation TikTokEventLogger

- (id)init
{
    if (self == nil) return nil;
    
    return [self initWithConfig:nil];
}

- (void)dealloc
{
    if (self.flushTimer) {
        [self.flushTimer invalidate];
        self.flushTimer = nil;
    }
}

- (id)initWithConfig:(TikTokConfig *)config
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
            
    NSUserDefaults *preferences = [TikTokDefaults storage];
    
    // flush timer logic
    if(config.initialFlushDelay && ![[preferences objectForKey:TikTokDefaultsKeyHasFirstFlushOccurred]  isEqual: @"true"]) {
        [self initializeFlushTimerWithSeconds:config.initialFlushDelay];
    } else {
        [self initializeFlushTimer];
    }
    
    self.config = config;
    
    self.logger = [TikTokFactory getLogger];
    
    self.requestHandler = [TikTokFactory getRequestHandler];
    
    self.loggerQueue = dispatch_queue_create("com.TikTokBusiness.TikTokEventLogger", DISPATCH_QUEUE_SERIAL);

    return self;
}

- (void)initializeFlushTimerWithSeconds:(long)seconds
{
    NSUserDefaults *preferences = [TikTokDefaults storage];
    tt_weakify(self)
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:seconds
        repeats:NO block:^(NSTimer *timer) {
        tt_strongify(self)
        if ([[preferences objectForKey:TikTokDefaultsKeyAreTimersOn]  isEqual: @"true"]) {
            [self flush:TikTokAppEventsFlushReasonTimer];
            [self flushMonitorEvents];
        }
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS
            repeats:YES block:^(NSTimer *timer) {
            tt_strongify(self)
            [self flush:TikTokAppEventsFlushReasonTimer];
            [self flushMonitorEvents];
        }];
    }];
}

- (void)initializeFlushTimer
{
    NSUserDefaults *defaults = [TikTokDefaults storage];
    tt_weakify(self)
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS
        repeats:YES block:^(NSTimer *timer) {
        tt_strongify(self)
        if ([[defaults objectForKey:TikTokDefaultsKeyAreTimersOn]  isEqual: @"true"]) {
            [self flush:TikTokAppEventsFlushReasonTimer];
            [self flushMonitorEvents];
        }
    }];
}

- (void)addEvent:(TikTokAppEvent *)event
{
    if([[TikTokBusiness getInstance] isRemoteSwitchOn] == NO) {
        [self.logger verbose:@"[TikTokAppEventQueue] Remote switch is off, no event added"];
        return;
    }
    if ([event.type isEqualToString:@"monitor"]) {
        dispatch_async(self.loggerQueue, ^{
            [[TikTokMonitorEventPersistence persistence] persistEvents:@[event]];
        });
    } else {
        dispatch_async(self.loggerQueue, ^{
            [[TikTokAppEventPersistence persistence] persistEvents:@[event]];
        });
    }
    
}

- (void)flush:(TikTokAppEventsFlushReason)flushReason
{
    if (!TTCheckValidString(self.config.appId)) {
        [self.logger info:@"[TikTokAppEventQueue] Invalid App ID, no flush logic invoked"];
        return;
    }
    
    if([[TikTokBusiness getInstance] isRemoteSwitchOn] == NO) {
        [self.logger info:@"[TikTokAppEventQueue] Remote switch is off, no flush logic invoked"];
        return;
    }
    
    if ([[TikTokBusiness getInstance] isGlobalConfigFetched] == NO) {
        [self.logger info:@"[TikTokAppEventQueue] Global config not fetched, no flush logic invoked"];
        return;
    }
    
    NSUserDefaults *preferences = [TikTokDefaults storage];
    
    // if there is initialFlushDelay, flush reason is not due to timer and first flush has not occurred, we don't flush
    if(self.config.initialFlushDelay && flushReason != TikTokAppEventsFlushReasonTimer && ![[preferences objectForKey:TikTokDefaultsKeyHasFirstFlushOccurred]  isEqual: @"true"]) {
        [self.logger info:@"[TikTokAppEventQueue] Flush logic not invoked due to delay for ATT"];
        return;
    }
    NSNumber *flushStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    if(![[preferences objectForKey:TikTokDefaultsKeyHasFirstFlushOccurred]  isEqual: @"true"]) {
        [preferences setObject:@"true" forKey:TikTokDefaultsKeyHasFirstFlushOccurred];
    }
    __block NSInteger flushSize = 0;
    tt_weakify(self)
    dispatch_sync(self.loggerQueue, ^{
        tt_strongify(self)
        @try {
            [self.logger info:@"[TikTokAppEventQueue] Start flush, with flush reason: %lu", flushReason];
            NSArray *eventsFromDisk = [[TikTokAppEventPersistence persistence] retrievePersistedEvents];
            [self.logger info:@"[TikTokAppEventQueue] Number events from disk: %lu", eventsFromDisk.count];
            NSMutableArray *eventsToBeFlushed = [NSMutableArray arrayWithArray:eventsFromDisk];
            flushSize = eventsToBeFlushed.count;
            dispatch_async(self.loggerQueue, ^{
                tt_strongify(self)
                [self realFlushEvents:eventsToBeFlushed forReason:flushReason isMonitor:NO];
            });
        } @catch (NSException *exception) {
            [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flush" exception:exception];
        }
    });
    if (flushSize > 0) {
        NSNumber *flushEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        NSDictionary *flushMeta = @{
            @"ts": flushEndTime,
            @"latency": [NSNumber numberWithLongLong:[flushEndTime longLongValue] - [flushStartTime longLongValue]],
            @"type": [self stringForReason:flushReason],
            @"interval": @(self.config.initialFlushDelay ?: FLUSH_PERIOD_IN_SECONDS),
            @"size":@(flushSize)
        };
        NSDictionary *monitorFlushProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"flush",
            @"meta": flushMeta
        };
        TikTokAppEvent *monitorFlushEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorFlushProperties withType:@"monitor"];
        [self addEvent:monitorFlushEvent];
    }
}


- (void)flushMonitorEvents {
    dispatch_async(self.loggerQueue, ^{
        @try {
            NSArray *eventsFromDisk =
            [[TikTokMonitorEventPersistence persistence] retrievePersistedEvents];
            NSMutableArray *eventsToBeFlushed = [NSMutableArray arrayWithArray:eventsFromDisk];
            [self realFlushEvents:eventsToBeFlushed forReason:TikTokAppEventsFlushReasonExplicitlyFlush isMonitor:YES];
        } @catch (NSException *exception) {
            [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flush" exception:exception];
        }
    });
}

- (void)realFlushEvents:(NSMutableArray *)eventsToBeFlushed
              forReason:(TikTokAppEventsFlushReason)flushReason
              isMonitor:(BOOL)isMonitor
{
    @try {
        [self.logger info:@"[TikTokAppEventQueue] Total number events to be flushed: %lu", eventsToBeFlushed.count];
        if(eventsToBeFlushed.count > 0) {
            if([TikTokBusiness isTrackingEnabled] && [[TikTokBusiness getInstance] accessToken] != nil && self.config.appId != nil) {
                // chunk eventsToBeFlushed into subarrays of API_LIMIT length or less and send requests for each
                NSMutableArray *eventChunks = [[NSMutableArray alloc] init];
                NSUInteger eventsRemaining = eventsToBeFlushed.count;
                int minIndex = 0;
                
                while(eventsRemaining > 0) {
                    NSRange range = NSMakeRange(minIndex, MIN(API_LIMIT, eventsRemaining));
                    NSArray *eventChunk = [eventsToBeFlushed subarrayWithRange:range];
                    [eventChunks addObject:eventChunk];
                    eventsRemaining -= range.length;
                    minIndex += range.length;
                }
                
                for (NSArray *eventChunk in eventChunks) {
                    if (isMonitor) {
                        [self.requestHandler sendMonitorRequest:eventChunk withConfig:self.config];
                    } else {
                        [self.requestHandler sendBatchRequest:eventChunk withConfig:self.config];
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flushing main queue" exception:exception];
    }
}

- (NSString *)stringForReason:(TikTokAppEventsFlushReason)reason {
    switch (reason) {
        case TikTokAppEventsFlushReasonTimer:
            return @"TIMER";
            break;
        case TikTokAppEventsFlushReasonEventThreshold:
            return @"THRESHOLD";
            break;
        case TikTokAppEventsFlushReasonEagerlyFlushingEvent:
            return @"IDENTIFY";
            break;
        case TikTokAppEventsFlushReasonAppBecameActive:
            return @"START_UP";
            break;
        case TikTokAppEventsFlushReasonExplicitlyFlush:
            return @"FORCE_FLUSH";
            break;
        case TikTokAppEventsFlushReasonLogout:
            return @"LOGOUT";
            break;
        default:
            return @"";
            break;
    }
}
@end
