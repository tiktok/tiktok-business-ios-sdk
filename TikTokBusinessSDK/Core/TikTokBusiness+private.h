//
//  TikTokBusiness+private.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/3/5.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokBusiness.h"
#import "TikTokEventLogger.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokBusiness()

@property (nonatomic, strong, nullable) TikTokEventLogger *eventLogger;

@property (nonatomic, assign) double exchangeErrReportRate;

/**
 * @brief This method is used internally to keep track of event logger state
 *        The event persistence is populated by several tracked events and then
 *        flushed every 15 seconds or when the event persistence has 100 events
*/
+ (TikTokEventLogger *)getEventLogger;

/**
 * @brief This method is used internally as the single consent gate.
 *        It returns YES when the app opted in to
 *        TikTokConfig.discardEventsWhileTrackingDisabled and tracking is currently
 *        disabled. Callers must then drop the event instead of persisting, queueing or
 *        transmitting it, and must not issue any request.
*/
+ (BOOL)shouldDiscardEvents;

// Optional diagnostic monitors require explicit local debug mode in consent mode.
+ (BOOL)canCollectDiagnosticEvents;

// A generation is invalidated synchronously on withdrawal. Queue work, request starts,
// and callbacks use the same lock as withdrawal so old work cannot cross reconsent.
+ (NSUInteger)trackingGeneration;
+ (BOOL)performWithTrackingGeneration:(NSUInteger)generation block:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
