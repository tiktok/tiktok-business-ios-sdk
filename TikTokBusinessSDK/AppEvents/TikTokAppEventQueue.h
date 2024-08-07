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
@property (nonatomic, strong, nullable) NSTimer *flushTimer;

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
 * @brief Clear cached events.
 */
- (void)clear;
@end

NS_ASSUME_NONNULL_END
