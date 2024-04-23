//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "TikTokAppEvent.h"
#import "TikTokAppEventUtility.h"
#import "TikTokConfig.h"
#import "TikTokLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokAppEventQueue : NSObject

/**
 * @brief Event queue as a mutable array
 */
@property (nonatomic, strong) NSMutableArray *eventQueue;

/**
 * @brief Monitor queue as a mutable array
 */
@property (nonatomic, strong) NSMutableArray *monitorQueue;

/**
 * @brief Timer for flush
 */
@property (nonatomic, strong) NSTimer *flushTimer;

/**
 * @brief Timer for logging
 */
@property (nonatomic, strong) NSTimer *logTimer;

/**
 * @brief Time in seconds until flush
 */
@property (nonatomic) int timeInSecondsUntilFlush;

/**
 * @brief Remaining events until flush
 */
@property (nonatomic) int remainingEventsUntilFlushThreshold;

/**
 * @brief Configuration from SDK initialization
 */
@property (nonatomic, strong, nullable) TikTokConfig *config;


- (id)init;

- (id)initWithConfig: (TikTokConfig * _Nullable)config;

/**
 * @brief Function called for flush timer updates (to account for before iOS 10)
 */
- (void)handleFlushTimerUpdate:(NSTimer*)timer;

/**
 * @brief Function called for log timer updates (to account for before iOS 10)
 */
- (void)handleLogTimerUpdate:(NSTimer*)timer;

/**
 * @brief Add event to queue
 */
- (void)addEvent:(TikTokAppEvent *)event;

/**
 * @brief Flush logic
 */
- (void)flush:(TikTokAppEventsFlushReason)flushReason;

/**
 * @brief Initialize flush timer with number of seconds
 */
- (void)initializeFlushTimerWithSeconds:(long)seconds;

/**
 * @brief Initialize flush timer with normal flush period
 */
- (void)initializeFlushTimer;

/**
 * @brief Initialize log timer
 */
- (void)initializeLogTimer;

@end

NS_ASSUME_NONNULL_END
