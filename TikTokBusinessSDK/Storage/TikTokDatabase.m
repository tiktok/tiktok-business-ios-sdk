//
//  TikTokDatabase.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/8/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokDatabase.h"
#import "TikTokErrorHandler.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokTypeUtility.h"
#import <sqlite3.h>
#import <pthread/pthread.h>

static NSString *TTDBDefaultTableName = @"TikTokBusiness.default.sqlite";
static pthread_mutex_t _abu_database_mutex = PTHREAD_MUTEX_INITIALIZER;

@interface TikTokDatabase ()

@property (nonatomic, copy) NSString *path;

@end

@implementation TikTokDatabase
{
    sqlite3 *_handler;
}

+ (instancetype)databaseWithName:(NSString *)name {
    pthread_mutex_lock(&_abu_database_mutex);
    TikTokDatabase *(^finish)(TikTokDatabase *) = ^(TikTokDatabase *db) {
        pthread_mutex_unlock(&_abu_database_mutex);
        return db;
    };
    NSString *tp = [self _tablePathWithName:name];
    sqlite3 *handler = nil;
    if (sqlite3_open(tp.UTF8String, &handler) != SQLITE_OK) {
        return finish(nil);
    }
    TikTokDatabase *database = [[TikTokDatabase alloc] init];
    database->_handler = handler;
    database.path = tp;
    [database closeDatabase];
    return finish(database);
}

+ (NSString *)_tablePathWithName:(NSString *)name {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    if (name == nil) return [documentsDirectory stringByAppendingPathComponent:TTDBDefaultTableName];
    if ([name hasSuffix:@".sqlite"]) return [documentsDirectory stringByAppendingPathComponent:name];
    return [documentsDirectory stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"sqlite"]];
}

- (BOOL)openDatabase {
    return sqlite3_open(self.path.UTF8String, &_handler) == SQLITE_OK;
}

- (BOOL)closeDatabase {
    return _handler != NULL && sqlite3_close(_handler) == SQLITE_OK;
}

- (BOOL)createTableWithName:(NSString *)tableName fields:(NSDictionary<NSString *, NSString *> *)fields {
    NSMutableString *createTableQuery = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (", tableName];
    
    NSInteger index = 0;
    for (NSString *fieldName in fields.allKeys) {
        NSString *fieldType = fields[fieldName];
        if (index > 0) {
            [createTableQuery appendString:@", "];
        }
        [createTableQuery appendFormat:@"%@ %@", fieldName, fieldType];
        index++;
    }
    [createTableQuery appendString:@");"];
    
    char *errorMessage;
    if (sqlite3_exec(_handler, [createTableQuery UTF8String], NULL, 0, &errorMessage) == SQLITE_OK) {
        return YES;
    } else {
        NSLog(@"Failed to create table %@: %s",tableName, errorMessage);
        sqlite3_free(errorMessage);
        return NO;
    }
}

- (BOOL)insertIntoTable:(NSString *)tableName fields:(NSDictionary<NSString *, id> *)fields {
    NSMutableString *insertQuery = [NSMutableString stringWithFormat:@"INSERT INTO %@ (", tableName];
    
    NSMutableArray<NSString *> *fieldNames = [NSMutableArray array];
    NSMutableArray<NSString *> *fieldValues = [NSMutableArray array];
    
    for (NSString *fieldName in fields.allKeys) {
        [fieldNames addObject:fieldName];
        [fieldValues addObject:@"?"];
    }
    
    [insertQuery appendString:[fieldNames componentsJoinedByString:@", "]];
    [insertQuery appendString:@") VALUES ("];
    [insertQuery appendString:[fieldValues componentsJoinedByString:@", "]];
    [insertQuery appendString:@");"];
    
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(_handler, [insertQuery UTF8String], -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare insert statement: %s", sqlite3_errmsg(_handler));
        return NO;
    }
    
    int index = 1;
    for (NSString *fieldName in fields.allKeys) {
        id value = fields[fieldName];
        if ([value isKindOfClass:[NSString class]]) {
            sqlite3_bind_text(statement, index, [value UTF8String], -1, SQLITE_STATIC);
        } else if ([value isKindOfClass:[NSNumber class]]) {
            sqlite3_bind_double(statement, index, [value doubleValue]);
        } else if ([value isKindOfClass:[NSData class]]) {
            sqlite3_bind_blob(statement, index, [value bytes], (int)[value length], SQLITE_STATIC);
        }
        index++;
    }
    
    if (sqlite3_step(statement) != SQLITE_DONE) {
        NSLog(@"Failed to insert data: %s", sqlite3_errmsg(_handler));
        sqlite3_finalize(statement);
        return NO;
    }
    
    sqlite3_finalize(statement);
    return YES;
}

- (NSArray<NSDictionary<NSString *, id> *> *)queryTable:(NSString *)tableName withWhere:(nullable NSString *)where orderBy:(TTDBOrderBy)orderBy limit:(TTDBLimit)limit {
    NSString *condition = [self _whereString:where];
    NSString *ob = [self _orderBy:orderBy];
    NSString *lt = [self _limit:limit];
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM '%@'%@%@%@;", tableName, condition, ob, lt];
    
    NSMutableArray<NSDictionary<NSString *, id> *> *results = [NSMutableArray array];
    
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(_handler, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare insert statement: %s", sqlite3_errmsg(_handler));
        return results;
    }
    
    int columns = sqlite3_column_count(statement);
    while (sqlite3_step(statement) == SQLITE_ROW) {
        NSMutableDictionary<NSString *, id> *row = [NSMutableDictionary dictionary];
        for (int i = 0; i < columns; i++) {
            const char *columnName = sqlite3_column_name(statement, i);
            NSString *key = [NSString stringWithUTF8String:columnName];
            switch (sqlite3_column_type(statement, i)) {
                case SQLITE_INTEGER:
                    row[key] = @(sqlite3_column_int(statement, i));
                    break;
                case SQLITE_FLOAT:
                    row[key] = @(sqlite3_column_double(statement, i));
                    break;
                case SQLITE_TEXT:
                    row[key] = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, i)];
                    break;
                case SQLITE_BLOB:
                    row[key] = [NSData dataWithBytes:(const void *)sqlite3_column_blob(statement, i) length:(NSUInteger)sqlite3_column_bytes(statement, i)];
                    break;
                case SQLITE_NULL:
                    row[key] = [NSNull null];
                    break;
            }
        }
        [results addObject:row];
    }
    
    sqlite3_finalize(statement);
    return results;
}

- (BOOL)deleteTable:(NSString *)tableName withWhere:(nullable NSString *)where orderBy:(TTDBOrderBy)orderBy limit:(TTDBLimit)limit {
    NSString *condition = [self _whereString:where];
    NSString *ob = [self _orderBy:orderBy];
    NSString *lt = [self _limit:limit];
    NSString *deleteQuery = [NSString stringWithFormat:@"DELETE FROM '%@'%@%@%@;", tableName, condition, ob, lt];
    
    char *errorMsg;
    if (sqlite3_exec(_handler, [deleteQuery UTF8String], NULL, 0, &errorMsg)!= SQLITE_OK) {
        NSLog(@"Failed to delete events: %s", errorMsg);
        sqlite3_free(errorMsg);
        return NO;
    }
    return YES;
}

- (BOOL)updateTable:(NSString *)tableName incrementField:(NSString *)incrementField value:(NSNumber *)incrementValue withWhere:(nullable NSString *)where {
    NSString *condition = [self _whereString:where];
    NSMutableString *updateQuery = [NSMutableString stringWithFormat:@"UPDATE %@ SET ", tableName];
    
    [updateQuery appendString:[NSString stringWithFormat:@"%@ = %@ + %@", incrementField, incrementField, [incrementValue stringValue]]];
    
    if (condition.length > 0) {
        [updateQuery appendFormat:@"%@", condition];
    }
    [updateQuery appendString:@";"];
    
    char *errorMessage;
    if (sqlite3_exec(_handler, [updateQuery UTF8String], NULL, 0, &errorMessage) == SQLITE_OK) {
        return YES;
    } else {
        NSLog(@"Failed to update: %s", errorMessage);
        sqlite3_free(errorMessage);
        return NO;
    }
}

- (NSInteger)getCount:(NSString *)tableName {
    if (![self openDatabase]) {
        [self closeDatabase];
        return 0;
    }
    NSString *countQuery = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", tableName];
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(_handler, [countQuery UTF8String], -1, &statement, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare count query statement: %s", sqlite3_errmsg(_handler));
        [self closeDatabase];
        return 0;
    }
    NSInteger rowCount = 0;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        rowCount = sqlite3_column_int(statement, 0);
    }
    sqlite3_finalize(statement);
    [self closeDatabase];
    return rowCount;
}

#pragma mark - Private
- (NSString *)_whereString:(NSString *)where {
    if(!TTCheckValidString(where)) return @"";
    return [@" WHERE " stringByAppendingString:where];
}

- (NSString *)_orderBy:(TTDBOrderBy)ob {
    if (ob.field == 0 || ob.order == 0) return @"";
    NSString *o = ob.order > 0 ? @"DESC" : @"ASC";
    return [NSString stringWithFormat:@" ORDER BY %s %@", ob.field, o];
}

- (NSString *)_limit:(TTDBLimit)limit {
    if (limit.count <= 0) return @"";
    return [NSString stringWithFormat:@" LIMIT %d OFFSET %d", limit.count, limit.offset];
}
@end
