//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokAppEvent.h"
#import "TikTokAppEventQueue.h"
#import "TikTokAppEventStore.h"
#import "TikTokAppEventUtility.h"
#import "TikTokBusiness.h"
#import "TikTokConfig.h"
#import "TikTokLogger.h"
#import "TikTokFactory.h"
#import "TikTokErrorHandler.h"
#import "TikTokTypeUtility.h"

#define APP_FLUSH_LIMIT 100
#define MONITOR_FLUSH_LIMIT 5
#define API_LIMIT 50
#define FLUSH_PERIOD_IN_SECONDS 15

@interface TikTokAppEventQueue()

@property (nonatomic, weak) id<TikTokLogger> logger;
@property (nonatomic, strong, nullable) TikTokRequestHandler *requestHandler;

@end

@implementation TikTokAppEventQueue

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
    
    self.eventQueue = [NSMutableArray array];
    self.monitorQueue = [NSMutableArray array];
            
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    // flush timer logic
    if(config.initialFlushDelay && ![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        [self initializeFlushTimerWithSeconds:config.initialFlushDelay];
    } else {
        [self initializeFlushTimer];
    }
    
    self.config = config;
    
    self.logger = [TikTokFactory getLogger];
    
    self.requestHandler = [TikTokFactory getRequestHandler];
    
    [self calculateAndSetRemainingEventThreshold];

    return self;
}

- (void)initializeFlushTimerWithSeconds:(long)seconds
{
    __weak TikTokAppEventQueue *weakSelf = self;
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:seconds
        repeats:NO block:^(NSTimer *timer) {
        if ([[preferences objectForKey:@"AreTimersOn"]  isEqual: @"true"]) {
            [weakSelf flush:TikTokAppEventsFlushReasonTimer];
        }
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS
            repeats:YES block:^(NSTimer *timer) {
            [weakSelf flush:TikTokAppEventsFlushReasonTimer];
        }];
    }];
}

- (void)initializeFlushTimer
{
    __weak TikTokAppEventQueue *weakSelf = self;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS
        repeats:YES block:^(NSTimer *timer) {
        if ([[defaults objectForKey:@"AreTimersOn"]  isEqual: @"true"]) {
            [weakSelf flush:TikTokAppEventsFlushReasonTimer];
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
        @synchronized (self) {
            [self.monitorQueue addObject:event];
        }
        if (self.monitorQueue.count >= MONITOR_FLUSH_LIMIT) {
            [self flushMonitorEvents];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"inMemoryMonitorQueueUpdated" object:nil];
    } else {
        @synchronized (self) {
            [self.eventQueue addObject:event];
        }
        if(self.eventQueue.count >= APP_FLUSH_LIMIT) {
            [self flush:TikTokAppEventsFlushReasonEventThreshold];
        }
        [self calculateAndSetRemainingEventThreshold];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"inMemoryEventQueueUpdated" object:nil];
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
    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    // if there is initialFlushDelay, flush reason is not due to timer and first flush has not occurred, we don't flush
    if(self.config.initialFlushDelay && flushReason != TikTokAppEventsFlushReasonTimer && ![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        [self.logger info:@"[TikTokAppEventQueue] Flush logic not invoked due to delay for ATT"];
        return;
    }
    NSNumber *flushStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    if(![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        [preferences setObject:@"true" forKey:@"HasFirstFlushOccurred"];
    }
    NSInteger flushSize = 0;
    @try {
        @synchronized (self) {
            [self.logger info:@"[TikTokAppEventQueue] Start flush, with flush reason: %lu current queue count: %lu", flushReason, self.eventQueue.count];
            NSArray *eventsFromDisk = [TikTokAppEventStore retrievePersistedAppEvents];
            [TikTokAppEventStore clearPersistedAppEvents];
            [self.logger info:@"[TikTokAppEventQueue] Number events from disk: %lu", eventsFromDisk.count];
            NSMutableArray *eventsToBeFlushed = [NSMutableArray arrayWithArray:eventsFromDisk];
            NSArray *copiedEventQueue = [self.eventQueue copy];
            [eventsToBeFlushed addObjectsFromArray:copiedEventQueue];
            flushSize = eventsToBeFlushed.count;
            [self.eventQueue removeAllObjects];
            [self calculateAndSetRemainingEventThreshold];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inMemoryEventQueueUpdated" object:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self flushOnMainQueue:eventsToBeFlushed forReason:flushReason isMonitor:NO];
            });
        }
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flush" exception:exception];
    }
    if (flushSize > 0) {
        NSNumber *flushEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        NSDictionary *flushMeta = @{
            @"ts": flushEndTime,
            @"latency": [NSNumber numberWithInt:[flushEndTime intValue] - [flushStartTime intValue]],
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
    @try {
        @synchronized (self) {
            NSArray *eventsFromDisk = [TikTokAppEventStore retrievePersistedMonitorEvents];
            [TikTokAppEventStore clearPersistedMonitorEvents];
            NSMutableArray *eventsToBeFlushed = [NSMutableArray arrayWithArray:eventsFromDisk];
            NSArray *copiedEventQueue = [self.monitorQueue copy];
            [eventsToBeFlushed addObjectsFromArray:copiedEventQueue];
            [self.monitorQueue removeAllObjects];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inMemoryMonitorQueueUpdated" object:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self flushOnMainQueue:eventsToBeFlushed forReason:TikTokAppEventsFlushReasonExplicitlyFlush isMonitor:YES];
            });
        }
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flush" exception:exception];
    }
}

- (void)flushOnMainQueue:(NSMutableArray *)eventsToBeFlushed
               forReason:(TikTokAppEventsFlushReason)flushReason
               isMonitor:(BOOL)isMonitor
{
    @try {
        [self.logger info:@"[TikTokAppEventQueue] Total number events to be flushed: %lu", eventsToBeFlushed.count];
        if(eventsToBeFlushed.count > 0) {
            if([[TikTokBusiness getInstance] isTrackingEnabled] && [[TikTokBusiness getInstance] accessToken] != nil && self.config.appId != nil) {
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
            } else {
                if (isMonitor) {
                    [TikTokAppEventStore persistMonitorEvents:eventsToBeFlushed];
                } else {
                    [TikTokAppEventStore persistAppEvents:eventsToBeFlushed];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                if([[TikTokBusiness getInstance] accessToken] == nil) {
                    [self.logger info:@"[TikTokAppEventQueue] Request not sent because access token is null"];
                }
            }
        }
        [self.logger info:@"[TikTokAppEventQueue] End flush, current queue count: %lu", self.eventQueue.count];
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flushing main queue" exception:exception];
    }
}

- (void)clear {
    [self.eventQueue removeAllObjects];
    [self.monitorQueue removeAllObjects];
}

- (void)calculateAndSetRemainingEventThreshold
{
    self.remainingEventsUntilFlushThreshold = APP_FLUSH_LIMIT - (int)self.eventQueue.count;
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
