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

#define TT_DB_LIMIT 500

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
        @"retry_times": @"INTEGER",
        @"sending": @"INTEGER",
        @"is_edp_event": @"INTEGER"
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
        if ([self eventsCount] > TT_DB_LIMIT) {
            return NO;
        }
        for (int i = 0; i < events.count; i++) {
            if (![[events objectAtIndex:i] isKindOfClass:[TikTokAppEvent class]]) {
                continue;
            }
            TikTokAppEvent *event = [events objectAtIndex:i];
            
            NSError *errorArchiving;
            NSData *eventData = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:YES error:&errorArchiving];
            if (errorArchiving) {
                NSLog(@"Failed to serialize event to data: %@", errorArchiving.localizedDescription);
                NSAssert(NO, @"Failed to serialize event to data: %@", errorArchiving.localizedDescription);
                [self.db closeDatabase];
                return NO;
            }
            if (![self.db insertIntoTable:[[self class] tableName] fields:@{
                @"event_data":eventData,
                @"ts": TTSafeString(event.timestamp),
                @"retry_times": @(event.retryTimes),
                @"sending": @(0),
                @"is_edp_event": @(event.isEDPEvent)
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
        NSString *whereCondition = @"sending = 0";
        NSArray *res = [self.db queryTable:[[self class] tableName] withWhere:whereCondition orderBy:TTDBOrderByNone limit:TTDBLimitNone];
        NSMutableArray *dbIDs = [NSMutableArray array];
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
                
                [dbIDs addObject:TTSafeString(event.dbID)];
            }
            if (!error && event) {
                [allEvents addObject:event];
            }
        }
        if (dbIDs.count > 0) {
            NSString *dbIDList = [dbIDs componentsJoinedByString:@", "];
            NSString *sendingWhereCondition = [NSString stringWithFormat:@"id IN (%@)",dbIDList];
            
            [self.db updateTable:[[self class] tableName] setField:@"sending" value:@(1) withWhere:sendingWhereCondition];
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
            [self.db updateTable:[[self class] tableName] setField:@"sending" value:@(0) withWhere:whereCondition];
            [self.db updateTable:[[self class] tableName] setField:@"retry_times" value:@"retry_times + 1" withWhere:whereCondition];
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

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self.db updateTable:[[self class] tableName] setField:@"sending" value:@(0) withWhere:nil];
    }
    return self;
}

+ (NSString *)tableName {
    return @"app_event_table";
}

- (BOOL)clearEDPEvents {
    NSString *edpCondition = @"is_edp_event = 1";
    if ([self.db openDatabase]) {
        if (![self.db deleteTable:[[self class] tableName] withWhere:edpCondition orderBy:TTDBOrderByNone limit:TTDBLimitNone]) {
            [self.db closeDatabase];
            return NO;
        }
    }
    return YES;
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

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self.db updateTable:[[self class] tableName] setField:@"sending" value:@(0) withWhere:nil];
    }
    return self;
}

+ (NSString *)tableName {
    return @"monitor_event_table";
}

@end
