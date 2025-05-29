//
//  TikTokDatabase.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/8/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, TTDBOrder) {
    TTDBOrderASC = -1,
    TTDBOrderDesc = 1,
};

typedef struct {
    TTDBOrder order;
    const char *field;
} TTDBOrderBy;

static inline
TTDBOrderBy TTDBOrderByMake(TTDBOrder order, NSString *field) {
    return (TTDBOrderBy){order, [field UTF8String]};
}

typedef struct {
    int offset;
    int count;
} TTDBLimit;

static inline TTDBLimit TTDBLimitMake(int offset, int count) {
    return (TTDBLimit){offset, count};
}

@interface TikTokDatabase : NSObject

+ (instancetype)databaseWithName:(NSString *)name;

- (BOOL)openDatabase;

- (BOOL)closeDatabase;

- (BOOL)createTableWithName:(NSString *)tableName fields:(NSDictionary<NSString *, NSString *> *)fields;

- (BOOL)insertIntoTable:(NSString *)tableName fields:(NSDictionary<NSString *, id> *)fields;

- (NSArray<NSDictionary<NSString *, id> *> *)queryTable:(NSString *)tableName withWhere:(nullable NSString *)where orderBy:(TTDBOrderBy)orderBy limit:(TTDBLimit)limit;

- (BOOL)deleteTable:(NSString *)tableName withWhere:(nullable NSString *)where orderBy:(TTDBOrderBy)orderBy limit:(TTDBLimit)limit;

- (BOOL)updateTable:(NSString *)tableName incrementField:(NSString *)incrementField value:(NSNumber *)incrementValue withWhere:(nullable NSString *)where;

- (NSInteger)getCount:(NSString *)tableName;


@end

NS_ASSUME_NONNULL_END
