//
//  TikTokSKANEventPersistence.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/8/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokSKANEventPersistence.h"
#import "TikTokDatabase.h"
#import "TikTokErrorHandler.h"
#import "TikTokAppEvent.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokTypeUtility.h"

@interface TikTokSKANEventPersistence ()

@property (nonatomic, strong) TikTokDatabase *db;

@end

@implementation TikTokSKANEventPersistence

+ (instancetype)persistence {
    static TikTokSKANEventPersistence *device = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        device = [[self alloc] init];
    });

    return device;
}

+ (NSString *)tableName {
    return @"skan_event_table";
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.db = [TikTokDatabase databaseWithName:NSStringFromClass([self class])];
        if ([self.db openDatabase]) {
            NSDictionary<NSString *, NSString *> *fields = @{
                @"id": @"INTEGER PRIMARY KEY AUTOINCREMENT",
                @"event_name": @"TEXT",
                @"value": @"DOUBLE",
                @"currency": @"TEXT"
            };
            if (![self.db createTableWithName:[[self class] tableName] fields:fields]) {
                [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to create table"];
            }
        } else {
            [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to open database"];
        }
        [self.db closeDatabase];
    }
    return self;
}

- (BOOL)persistSKANEventWithName:(NSString *)eventName value:(NSNumber *)value currency:(nullable TTCurrency)currency {
    if ([self.db openDatabase]) {
        if (![self.db insertIntoTable:[[self class] tableName] fields:@{
            @"event_name":TTSafeString(eventName),
            @"value": value?:@(0),
            @"currency": TTSafeString(currency)
        }]) {
            return NO;
        }
    }
    [self.db closeDatabase];
    return YES;
}

- (NSArray *)retrievePersistedEvents {
    NSArray *res = [NSArray array];
    if ([self.db openDatabase]) {
        res = [self.db queryTable:[[self class] tableName] withWhere:nil orderBy:TTDBOrderByNone limit:TTDBLimitNone];
    }
    [self.db closeDatabase];
    return res.copy;
}

@end
