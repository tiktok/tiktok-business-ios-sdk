//
//  TikTokBaseEvent.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/5.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import "TikTokBaseEvent.h"
#import "TikTokTypeUtility.h"

@implementation TikTokBaseEvent

- (instancetype)initWithEventName:(NSString *)eventName {
    return [self initWithEventName:eventName eventId:nil];
}

- (instancetype)initWithEventName:(NSString *)eventName eventId:(NSString *_Nullable)eventId {
    return [self initWithEventName:eventName properties:@{} eventId:eventId];
}

- (instancetype)initWithEventName:(NSString *)eventName properties:(NSDictionary *)properties eventId:(NSString *_Nullable)eventId {
    self = [super init];
    if (self) {
        self.eventName = eventName;
        self.properties = properties;
        self.eventId = eventId;
    }
    return self;
}

+ (instancetype)eventWithName:(NSString *)eventName {
    return [[TikTokBaseEvent alloc] initWithEventName:eventName properties:@{} eventId:nil];
}

- (instancetype)addPropertyWithKey:(NSString *)key value:(nullable id)value {
    NSMutableDictionary *newProperties = [self.properties mutableCopy];
    if (!TTCheckValidDictionary(newProperties)) {
        newProperties = [NSMutableDictionary dictionary];
    }
    [TikTokTypeUtility dictionary:newProperties setObject:value forKey:key];
    self.properties = newProperties.copy;
    return self;
}

@end
