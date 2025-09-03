//
//  TikTokBaseEventPersistence.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/8/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokBaseEventPersistence.h"
#import "TikTokDatabase.h"
#import "TikTokErrorHandler.h"
#import "TikTokAppEvent.h"
#import "TikTokBUsinessSDKMacros.h"
#import "TikTokTypeUtility.h"

@interface TikTokBaseEventPersistence ()

@property (nonatomic, strong) TikTokDatabase *db;

@end

@implementation TikTokBaseEventPersistence

+ (instancetype)persistence {
    static TikTokBaseEventPersistence *persistence = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        persistence = [[self alloc] init];
    });

    return persistence;
}

+ (NSDictionary *)tableFields {
    NSDictionary<NSString *, NSString *> *fields = @{
        @"id": @"INTEGER PRIMARY KEY AUTOINCREMENT",
        @"event_data": @"BLOB",
        @"ts": @"TEXT",
        @"retry_times": @"INTEGER"
    };
    return fields;
}

+ (NSString *)tableName {
    return @"";
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.db = [TikTokDatabase databaseWithName:NSStringFromClass([self class])];
        if ([self.db openDatabase]) {
            
            if (![self.db createTableWithName:[[self class] tableName] fields:[[self class] tableFields]]) {
                [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to create table"];
            }
        } else {
            [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to open database"];
        }
    }
    return self;
}

- (BOOL)persistEvents:(NSArray *)events {
    if ([self.db openDatabase]) {
        for (int i = 0; i < events.count; i++) {
            if (![[events objectAtIndex:i] isKindOfClass:[TikTokAppEvent class]]) {
                continue;
            }
            TikTokAppEvent *event = [events objectAtIndex:i];
            
            NSError *errorArchiving;
            NSData *eventData = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:YES error:&errorArchiving];
            if (errorArchiving) {
                NSLog(@"Failed to serialize event to data: %@", errorArchiving.localizedDescription);
                [self.db closeDatabase];
                return NO;
            }
            if (![self.db insertIntoTable:[[self class] tableName] fields:@{
                @"event_data":eventData,
                @"ts": TTSafeString(event.timestamp),
                @"retry_times": @(event.retryTimes)
            }]) {
                [self.db closeDatabase];
                return NO;
            }
        }
        
    }
    return YES;
}

- (NSArray *)retrievePersistedEvents {
    NSMutableArray *allEvents = [NSMutableArray array];
    if ([self.db openDatabase]) {
        NSArray *res = [self.db queryTable:[[self class] tableName] withWhere:nil orderBy:TTDBOrderByNone limit:TTDBLimitNone];
        for (NSDictionary *row in res) {
            if (!TTCheckValidDictionary(row)) {
                continue;
            }
            NSData *eventData = [row objectForKey:@"event_data"];
            NSInteger eID = [[row objectForKey:@"id"] integerValue];
            NSInteger retry_times = [[row objectForKey:@"retry_times"] integerValue];
            NSError *error;
            id obj = [NSKeyedUnarchiver unarchivedObjectOfClass:[TikTokAppEvent class] fromData:eventData error:&error];
            TikTokAppEvent *event = nil;
            if ([obj isKindOfClass:[TikTokAppEvent class]]) {
                event = (TikTokAppEvent *)obj;
                event.dbID = [NSString stringWithFormat:@"%ld",(long)eID];
                event.retryTimes = retry_times;
            }
            if (!error && event) {
                [allEvents addObject:event];
            }
        }
    }
    return allEvents.copy;
}

- (NSInteger)eventsCount {
    return [self.db getCount:[[self class] tableName]];
}

- (BOOL)clearEvents{
    if ([self.db openDatabase]) {
        if (![self.db deleteTable:[[self class] tableName] withWhere:nil orderBy:TTDBOrderByNone limit:TTDBLimitNone]) {
            [self.db closeDatabase];
            return NO;
        }
    }
    return YES;
}

- (BOOL)handleSentResult:(BOOL)success events:(NSArray *)events {
    if ([self.db openDatabase]) {
        NSMutableArray *dbIDs = [NSMutableArray array];
        for(id obj in events) {
            if ([obj isKindOfClass:[TikTokAppEvent class]]) {
                TikTokAppEvent *event = (TikTokAppEvent *)obj;
                [dbIDs addObject:TTSafeString(event.dbID)];
            }
        }
        NSString *dbIDList = [dbIDs componentsJoinedByString:@", "];
        NSString *whereCondition = [NSString stringWithFormat:@"id IN (%@)",dbIDList];
        if (success) {
            [self.db deleteTable:[[self class] tableName] withWhere:whereCondition orderBy:TTDBOrderByNone limit:TTDBLimitNone];
        } else {
            [self.db updateTable:[[self class] tableName] incrementField:@"retry_times" value:@(1) withWhere:whereCondition];
        }
    }
    return YES;
}

@end


@implementation TikTokAppEventPersistence

+ (instancetype)persistence {
    static TikTokAppEventPersistence *device = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        device = [[self alloc] init];
    });

    return device;
}

+ (NSString *)tableName {
    return @"app_event_table";
}

@end


@implementation TikTokMonitorEventPersistence

+ (instancetype)persistence {
    static TikTokMonitorEventPersistence *device = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        device = [[self alloc] init];
    });

    return device;
}

+ (NSString *)tableName {
    return @"monitor_event_table";
}

@end
