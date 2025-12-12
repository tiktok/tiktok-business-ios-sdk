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
#import "TikTokBusinessSDKMacros.h"
#import "TikTokTypeUtility.h"

#define TIKTOKSDK_EVENTNAME_KEY @"eventName"
#define TIKTOKSDK_TIMESTAMP_KEY @"timestamp"
#define TIKTOKSDK_PROPERTIES_KEY @"properties"
#define TIKTOKSDK_TTEVENTID_KEY @"eventID"
#define TIKTOKSDK_DEDUPEVENTID_KEY @"dedupeventID"
#define TIKTOKSDK_TYPE_KEY @"type"
#define TIKTOKSDK_USERINFO_KEY @"userInfo"
#define TIKTOKSDK_ANONYMOUSID_KEY @"anonymousID"
#define TIKTOKSDK_DBID_KEY @"dbID"
#define TIKTOKSDK_RETRYTIMES_KEY @"retryTimes"
#define TIKTOKSDK_SCREENSHOT_KEY @"screenshot"

@implementation TikTokAppEvent

- (instancetype)initWithEventName:(NSString *)eventName
{
    return [self initWithEventName:eventName withProperties:@{} withEventID:@""];
    
}

- (instancetype)initWithEventName:(NSString *)eventName
         withType: (NSString *)type
{
    return [self initWithEventName:eventName withProperties:@{} withType:type withEventId:@""];
    
}

- (instancetype)initWithEventName:(NSString *)eventName
                   withProperties:(NSDictionary *)properties
                      withEventID:(NSString *)eventID
{
    NSString * type = @"track";
    if ([eventName isEqual:@"MonitorEvent"]) {
        type = @"monitor";
    }
    return [self initWithEventName:eventName withProperties:properties withType:type withEventId:eventID];
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
    NSMutableDictionary *realProperties = [NSMutableDictionary dictionary];
    NSMutableDictionary *tmpProperty = properties.mutableCopy;
    if (TTCheckValidDictionary(tmpProperty)) {
        NSString *apiPlatformStr = [tmpProperty objectForKey:@"api_platform"];
        if (TTCheckValidString(apiPlatformStr)) {
            [realProperties setObject:apiPlatformStr forKey:@"api_platform"];
            [tmpProperty removeObjectForKey:@"api_platform"];
        }
        NSString *monitorType = [tmpProperty objectForKey:@"monitor_type"];
        if (TTCheckValidString(monitorType) && [monitorType isEqualToString:@"enhanced_data_postback"]) {
            [realProperties setObject:tmpProperty forKey:@"meta"];
            [realProperties setObject:@"edp" forKey:@"track_source"];
        } else {
            [realProperties addEntriesFromDictionary:tmpProperty];
        }
    }
    [realProperties setValue:TTSafeString(eventID) forKey:@"tt_event_id"];
    self.properties = realProperties.copy;
    self.anonymousID = [[TikTokIdentifyUtility sharedInstance] getOrGenerateAnonymousID];
    self.userInfo = [[TikTokIdentifyUtility sharedInstance] getUserInfoDictionary];
    self.type = type;
    self.tteventID = TTSafeString(eventID);
    self.dbID = @"";
    self.retryTimes = 0;
    self.eventID = [[NSUUID UUID] UUIDString];
    self.screenshot = nil;
   
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    TikTokAppEvent *copy = [[[self class] allocWithZone:zone] init];
    
    if (copy) {
        copy.eventName = [self.eventName copyWithZone:zone];
        copy.timestamp = [self.timestamp copyWithZone:zone];
        copy.properties = [self.properties copyWithZone:zone];
        copy.tteventID = [self.tteventID copyWithZone:zone];
        copy.eventID = [self.eventID copyWithZone:zone];
        copy.anonymousID = [self.anonymousID copyWithZone:zone];
        copy.userInfo = [self.userInfo copyWithZone:zone];
        copy.type = [self.type copyWithZone:zone];
        copy.dbID = [self.dbID copyWithZone:zone];
        copy.retryTimes = self.retryTimes;
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
    [encoder encodeObject:self.tteventID forKey:TIKTOKSDK_TTEVENTID_KEY];
    [encoder encodeObject:self.eventID forKey:TIKTOKSDK_DEDUPEVENTID_KEY];
    [encoder encodeObject:self.type forKey:TIKTOKSDK_TYPE_KEY];
    [encoder encodeObject:self.anonymousID forKey:TIKTOKSDK_ANONYMOUSID_KEY];
    [encoder encodeObject:self.userInfo forKey:TIKTOKSDK_USERINFO_KEY];
    [encoder encodeObject:self.dbID forKey:TIKTOKSDK_DBID_KEY];
    [encoder encodeInteger:self.retryTimes forKey:TIKTOKSDK_RETRYTIMES_KEY];
    [encoder encodeObject:self.screenshot forKey:TIKTOKSDK_SCREENSHOT_KEY];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
    if(self = [super init]) {
        self.eventName = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_EVENTNAME_KEY];
        self.timestamp = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_TIMESTAMP_KEY];
        NSSet *clsSet = [NSSet setWithObjects:[NSDictionary class], [NSString class],[NSArray class],[NSNumber class], nil];
        self.properties = [decoder decodeObjectOfClasses:clsSet forKey:TIKTOKSDK_PROPERTIES_KEY];
        self.tteventID = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_TTEVENTID_KEY];
        self.eventID = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_DEDUPEVENTID_KEY];
        self.anonymousID = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_ANONYMOUSID_KEY];
        self.type = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_TYPE_KEY];
        self.userInfo = [decoder decodeObjectOfClasses:clsSet forKey:TIKTOKSDK_USERINFO_KEY];
        self.dbID = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_DBID_KEY];
        self.retryTimes = [decoder decodeIntegerForKey:TIKTOKSDK_RETRYTIMES_KEY];
        self.screenshot = [decoder decodeObjectOfClass:[NSString class] forKey:TIKTOKSDK_SCREENSHOT_KEY];
    }
    return self;
}

@end
