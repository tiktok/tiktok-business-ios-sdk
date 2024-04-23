//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TikTokAppEventQueue;

@interface TikTokAppEventStore : NSObject

/**
 * @brief Method to clear persisted app events
 */
+ (void)clearPersistedAppEvents;

/**
 * @brief Method to read events in disk, append events in queue, and write combined into disk
 */
+ (void)persistAppEvents:(NSArray *)queue;

/**
 * @brief Method to return the array of saved app event states and deletes them.
 */
+ (NSArray *)retrievePersistedAppEvents;

@end

NS_ASSUME_NONNULL_END
