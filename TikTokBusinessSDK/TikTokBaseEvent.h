//
//  TikTokBaseEvent.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/5.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokBaseEvent : NSObject

@property (nonatomic, strong) NSDictionary *properties;
@property (nonatomic, strong) NSString *eventName;
@property (nonatomic, strong) NSString *eventId;

- (instancetype)initWithEventName:(NSString *)eventName;
- (instancetype)initWithEventName:(NSString *)eventName eventId:(NSString *_Nullable)eventId;
- (instancetype)initWithEventName:(NSString *)eventName properties:(NSDictionary *)properties eventId:(NSString *_Nullable)eventId;
+ (instancetype)eventWithName:(NSString *)eventName;
- (instancetype)addPropertyWithKey:(NSString *)key value:(nullable id)value;
@end

NS_ASSUME_NONNULL_END
