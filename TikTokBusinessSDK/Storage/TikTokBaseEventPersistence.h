//
//  TikTokBaseEventPersistence.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/8/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokDatabase.h"

static const TTDBOrderBy TTDBOrderByNone = {0, 0};
static const TTDBLimit TTDBLimitNone = {0, 0};

NS_ASSUME_NONNULL_BEGIN

@interface TikTokBaseEventPersistence : NSObject

+ (instancetype)persistence;

+ (NSString *)tableName;

- (BOOL)persistEvents:(NSArray *)events;

- (NSArray *)retrievePersistedEvents;

- (NSInteger)eventsCount;

- (BOOL)clearEvents;

- (BOOL)handleSentResult:(BOOL)success events:(NSArray *)events;

@end

@interface TikTokAppEventPersistence : TikTokBaseEventPersistence

@end

@interface TikTokMonitorEventPersistence : TikTokBaseEventPersistence

@end

NS_ASSUME_NONNULL_END
