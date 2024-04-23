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

#define FLUSH_LIMIT 100
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
    
    [self initializeLogTimer];
    
    self.config = config;
    
    self.logger = [TikTokFactory getLogger];
    
    self.requestHandler = [TikTokFactory getRequestHandler];
    
    [self calculateAndSetRemainingEventThreshold];

    return self;
}

// function used for pre iOS 10, since selector takes timer as an argument
- (void)handleFlushTimerUpdate:(NSTimer*)timer
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];

    __weak TikTokAppEventQueue *weakSelf = self;
    if ([[preferences objectForKey:@"AreTimersOn"]  isEqual: @"true"]) {
        [weakSelf flush:TikTokAppEventsFlushReasonTimer];
    }
}

// function used for pre iOS 10, since selector takes timer as an argument
- (void)handleFlushTimerUpdateOnFirstFlush:(NSTimer*)timer
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    __weak TikTokAppEventQueue *weakSelf = self;
    if ([[preferences objectForKey:@"AreTimersOn"]  isEqual: @"true"]) {
        [weakSelf flush:TikTokAppEventsFlushReasonTimer];
    }
    // return to normal 15 second timer after first flush
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS target:self selector:@selector(handleFlushTimerUpdate:) userInfo:nil repeats:YES];
}

// function used for pre iOS 10, since selector takes timer as an argument
- (void)handleLogTimerUpdate:(NSTimer*)timer
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    if ([[preferences objectForKey:@"AreTimersOn"]  isEqual: @"true"]) {

        NSDate *fireDate = [self.flushTimer fireDate];
        NSDate *nowDate = [NSDate date];
        self.timeInSecondsUntilFlush = [fireDate timeIntervalSinceDate:nowDate];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"timeLeft" object:nil];
    }
}

- (void)initializeFlushTimerWithSeconds:(long)seconds
{
    __weak TikTokAppEventQueue *weakSelf = self;
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];

    if(@available(iOS 10, *)){
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
    } else {
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(handleFlushTimerUpdateOnFirstFlush:) userInfo:nil repeats:YES];
    }
}

- (void)initializeFlushTimer
{
    __weak TikTokAppEventQueue *weakSelf = self;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if(@available(iOS 10, *)){
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS
            repeats:YES block:^(NSTimer *timer) {
            if ([[defaults objectForKey:@"AreTimersOn"]  isEqual: @"true"]) {
                [weakSelf flush:TikTokAppEventsFlushReasonTimer];
            }
        }];
    } else {
        self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:FLUSH_PERIOD_IN_SECONDS target:self selector:@selector(handleFlushTimerUpdate:) userInfo:nil repeats:YES];
    }
}

- (void)initializeLogTimer
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if(@available(iOS 10, *)){
        self.logTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *time) {
            if([[defaults objectForKey:@"AreTimersOn"]  isEqual: @"true"]){
                NSDate *fireDate = [self.flushTimer fireDate];
                NSDate *nowDate = [NSDate date];
                self.timeInSecondsUntilFlush = [fireDate timeIntervalSinceDate:nowDate];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"timeLeft" object:nil];
            }
        }];
    } else {
        self.logTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(handleLogTimerUpdate:) userInfo:nil repeats:YES];
    }
}

- (void)addEvent:(TikTokAppEvent *)event
{
    if([[TikTokBusiness getInstance] isRemoteSwitchOn] == NO) {
        [self.logger verbose:@"[TikTokAppEventQueue] Remote switch is off, no event added"];
        return;
    }
    [self.eventQueue addObject:event];
    if(self.eventQueue.count >= FLUSH_LIMIT) {
        [self flush:TikTokAppEventsFlushReasonEventThreshold];
    }
    [self calculateAndSetRemainingEventThreshold];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"inMemoryEventQueueUpdated" object:nil];
}

- (void)flush:(TikTokAppEventsFlushReason)flushReason
{
    if([[TikTokBusiness getInstance] isRemoteSwitchOn] == NO) {
        [self.logger info:@"[TikTokAppEventQueue] Remote switch is off, no flush logic invoked"];
        return;
    }
    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    // if there is initialFlushDelay, flush reason is not due to timer and first flush has not occurred, we don't flush
    if(self.config.initialFlushDelay && flushReason != TikTokAppEventsFlushReasonTimer && ![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        [self.logger info:@"[TikTokAppEventQueue] Flush logic not invoked due to delay for ATT"];
        return;
    }
    
    if(![[preferences objectForKey:@"HasFirstFlushOccurred"]  isEqual: @"true"]) {
        [preferences setObject:@"true" forKey:@"HasFirstFlushOccurred"];
    }
    
    @try {
        @synchronized (self) {
            [self.logger info:@"[TikTokAppEventQueue] Start flush, with flush reason: %lu current queue count: %lu", flushReason, self.eventQueue.count];
            NSArray *eventsFromDisk = [TikTokAppEventStore retrievePersistedAppEvents];
            [TikTokAppEventStore clearPersistedAppEvents];
            [self.logger info:@"[TikTokAppEventQueue] Number events from disk: %lu", eventsFromDisk.count];
            NSMutableArray *eventsToBeFlushed = [NSMutableArray arrayWithArray:eventsFromDisk];
            NSArray *copiedEventQueue = [self.eventQueue copy];
            [eventsToBeFlushed addObjectsFromArray:copiedEventQueue];
            [self.eventQueue removeAllObjects];
            [self calculateAndSetRemainingEventThreshold];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inMemoryEventQueueUpdated" object:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self flushOnMainQueue:eventsToBeFlushed forReason:flushReason];
            });
        }
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flush" exception:exception];
    }
}

- (void)flushOnMainQueue:(NSMutableArray *)eventsToBeFlushed
               forReason:(TikTokAppEventsFlushReason)flushReason
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
                    [self.requestHandler sendBatchRequest:eventChunk withConfig:self.config];
                }
            } else {
                [TikTokAppEventStore persistAppEvents:eventsToBeFlushed];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
                if([[TikTokBusiness getInstance] accessToken] == nil) {
                    [self.logger info:@"[TikTokAppEventQueue] Request not sent because access token is null"];
                }
                if(self.config.appId == nil) {
                    [self.logger info:@"[TikTokAppEventQueue] Request not sent because application ID is null"];
                }
            }
        }
        [self.logger info:@"[TikTokAppEventQueue] End flush, current queue count: %lu", self.eventQueue.count];
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failure on flushing main queue" exception:exception];
    }
}

- (void)calculateAndSetRemainingEventThreshold
{
    self.remainingEventsUntilFlushThreshold = FLUSH_LIMIT - (int)self.eventQueue.count;
}

@end
