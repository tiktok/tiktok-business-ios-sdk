//
//  TikTokEventLogger.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/10/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokAppEvent.h"
#import "TikTokAppEventUtility.h"
#import "TikTokConfig.h"
#import "TikTokLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokEventLogger : NSObject

/**
 * @brief Timer for flush
 */
@property (nonatomic, strong, nullable) NSTimer *flushTimer;

/**
 * @brief Time in seconds until flush
 */
@property (nonatomic) int timeInSecondsUntilFlush;

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

@end

NS_ASSUME_NONNULL_END
