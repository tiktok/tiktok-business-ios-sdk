//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "TikTokBusinessSDKMacros.h"
#import "TikTokConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class TikTokAppEventQueue;

@interface TikTokAppEventStore : NSObject

/**
 * @brief Method to clear persisted app events
 */
+ (void)clearPersistedAppEvents;

/**
 * @brief Method to clear persisted monitor events
 */
+ (void)clearPersistedMonitorEvents;

/**
 * @brief Method to clear persisted SKAN events
 */
+ (void)clearPersistedSKANEvents;

/**
 * @brief Method to read app events in disk, append events in queue, and write combined into disk
 */
+ (void)persistAppEvents:(NSArray *)queue;

/**
 * @brief Method to read monitor events in disk, append events in queue, and write combined into disk
 */
+ (void)persistMonitorEvents:(NSArray *)queue;

/**
 * @brief Method to read SKAN events in disk, append event in queue, and write combined into disk
 */
+ (void)persistSKANEventWithName:(NSString *)eventName value:(NSNumber *)value currency:(nullable TTCurrency)currency;

/**
 * @brief Method to return the array of saved app event states.
 */
+ (NSArray *)retrievePersistedAppEvents;

/**
 * @brief Method to return the array of saved monitor event states.
 */
+ (NSArray *)retrievePersistedMonitorEvents;

/**
 * @brief Method to return the array of saved SKAN event states.
 */
+ (NSArray *)retrievePersistedSKANEvents;

/**
 * @brief Method to return the number of saved app event.
 */
+ (NSUInteger)persistedAppEventsCount;

@end

NS_ASSUME_NONNULL_END
