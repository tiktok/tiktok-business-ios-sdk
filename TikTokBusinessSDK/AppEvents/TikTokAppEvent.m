//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokAppEvent.h"
#import "TikTokAppEventUtility.h"
#import "TikTokBusiness.h"
#import "TikTokIdentifyUtility.h"

#define TIKTOKSDK_EVENTNAME_KEY @"eventName"
#define TIKTOKSDK_TIMESTAMP_KEY @"timestamp"
#define TIKTOKSDK_PROPERTIES_KEY @"properties"
#define TIKTOKSDK_EVENTID_KEY @"eventID"

@implementation TikTokAppEvent

- (instancetype)initWithEventName:(NSString *)eventName
{
    return [self initWithEventName:eventName withProperties:@{}];
    
}

- (instancetype)initWithEventName:(NSString *)eventName
         withType: (NSString *)type
{
    return [self initWithEventName:eventName withProperties:@{} withType:type withEventId:@""];
    
}

- (instancetype)initWithEventName:(NSString *)eventName
         withProperties: (NSDictionary *)properties
{
    NSString * type = @"track";
    if ([eventName isEqual:@"MonitorEvent"]) {
        type = @"monitor";
    }
    
    return [self initWithEventName:eventName withProperties:properties withType:type withEventId:@""];
}

- (instancetype)initWithEventName: (NSString *)eventName
                   withProperties: (NSDictionary *)properties
                         withType: (NSString *)type {
    return [self initWithEventName:eventName withProperties:properties withType:type withEventId:@""];
}

- (instancetype)initWithEventName:(NSString *)eventName
         withProperties: (NSDictionary *)properties
               withType: (NSString *)type
            withEventId:(nonnull NSString *)eventID
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    self.eventName = eventName;
    self.timestamp = [TikTokAppEventUtility getCurrentTimestampInISO8601];
    self.properties = properties;
    self.anonymousID = [[TikTokIdentifyUtility sharedInstance] getOrGenerateAnonymousID];
    self.userInfo = [[TikTokIdentifyUtility sharedInstance] getUserInfoDictionary];
    self.type = type;
    self.eventID = eventID;
   
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    TikTokAppEvent *copy = [[[self class] allocWithZone:zone] init];
    
    if (copy) {
        copy->_eventName = [self.eventName copyWithZone:zone];
        copy->_timestamp = [self.timestamp copyWithZone:zone];
        copy.properties = [self.properties copyWithZone:zone];
        copy.eventID = [self.eventID copyWithZone:zone];
    }
    
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)encoder
{
    [encoder encodeObject:self.eventName forKey:TIKTOKSDK_EVENTNAME_KEY];
    [encoder encodeObject:self.timestamp forKey:TIKTOKSDK_TIMESTAMP_KEY];
    [encoder encodeObject:self.properties forKey:TIKTOKSDK_PROPERTIES_KEY];
    [encoder encodeObject:self.eventID forKey:TIKTOKSDK_EVENTID_KEY];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
    NSString *eventName = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_EVENTNAME_KEY];
    NSString *timestamp = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_TIMESTAMP_KEY];
    NSDictionary *properties = [decoder decodeObjectOfClass:[NSDictionary class] forKey:TIKTOKSDK_PROPERTIES_KEY];
    NSString *eventID = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_EVENTID_KEY];
    if(self = [self initWithEventName:eventName]) {
        self.eventName = eventName;
        self.timestamp = timestamp;
        self.properties = properties;
        self.eventID = eventID;
    }
    return self;
}

@end
