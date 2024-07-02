//
//  TikTokBusiness+private.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/3/5.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokAppEventQueue.h"
#import "TikTokBusiness.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokBusiness()

@property (nonatomic, strong, nullable) TikTokAppEventQueue *queue;
@property (nonatomic, assign) double exchangeErrReportRate;

/**
 * @brief This method is used internally to keep track of event queue state
 *        The event queue is populated by several tracked events and then
 *        flushed to the Marketing API endpoint every 15 seconds or when the
 *        event queue has 100 events
*/
+ (TikTokAppEventQueue *)getQueue;

@end

NS_ASSUME_NONNULL_END
