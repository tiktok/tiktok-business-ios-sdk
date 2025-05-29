//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokErrorHandler.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokFactory.h"
#import "TikTokTypeUtility.h"
#import "TikTokRequestHandler.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokBusinessSDKAddress.h"

#define TTSDK_CRASH_PATH_NAME @"monitoring"
#define TTSDK_KEYWORDS  [NSArray arrayWithObjects: @"TikTokBusinessSDK",nil]

extern void * TikTokBusinessSDKFuncBeginAddress(void);
extern void * TikTokBusinessSDKFuncEndAddress(void);

static NSString *directoryPath;

NSString *const kTTSDKCrashInfo = @"crash_info";
NSString *const kTTSDKCrashReason = @"Exception Reason";
NSString *const kTTSDKCrashName = @"Exception Name";
NSString *const kTTSDKCrashReportID = @"crash_log_id";
NSString *const kTTSDKCrashSDKVeriosn = @"crash_sdk_version";
NSString *const kTTSDKCrashTimestamp = @"timestamp";
NSString *const kTTSDKVersion = @"TikTok SDK Version";

@implementation TikTokErrorHandler

+ (NSString *)initDirectPath
{
    NSSearchPathDirectory directory = NSLibraryDirectory;
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    NSString *dirPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:TTSDK_CRASH_PATH_NAME];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:dirPath]) {
      [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:NO attributes:NULL error:NULL];
    }
    return dirPath;
}

+ (NSString *)getCrashReportPathWithCrashReportId:(NSString *)crashReportId
                                 currentTimestamp:(NSString *)currentTimestamp
{
    return [directoryPath stringByAppendingPathComponent: [NSString stringWithFormat:@"crash-log_%@_%@.json", currentTimestamp, crashReportId]];
}

+ (void)handleErrorWithOrigin:(NSString *)origin
                      message:(NSString *)message
                    exception:(NSException *)exception {
    [[TikTokFactory getLogger] error:@"[%@] %@ (%@) \n %@", origin, message, exception, [exception callStackSymbols]];
}

+ (void)handleErrorWithOrigin:(NSString *)origin
                      message:(NSString *)message {
    [[TikTokFactory getLogger] error:@"[%@] %@", origin, message];
}

+ (void)clearCrashReportFiles
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:directoryPath error:nil];
    for (NSUInteger i = 0; i < files.count; i++) {
        // remove all crash log files
        if ([[TikTokErrorHandler array:files objectAtIndex:i] hasPrefix:@"crash-log"]) {
            [fileManager removeItemAtPath:[directoryPath stringByAppendingPathComponent:[TikTokErrorHandler array:files objectAtIndex:i]] error:nil];
        }
    }
}

+ (NSDictionary<NSString *, id> *)getLastestCrashLog
{
    return [TikTokErrorHandler array:[TikTokErrorHandler loadCrashLogs] objectAtIndex:0];
}

+ (NSArray<NSDictionary<NSString *, id> *> *)loadCrashLogs
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    directoryPath = [TikTokErrorHandler initDirectPath];
    NSArray<NSString *> *fileNames = [fileManager contentsOfDirectoryAtPath:directoryPath error:NULL];
    NSArray<NSString *> *crashLogFiles = [[TikTokErrorHandler _getCrashLogFileNames:fileNames] sortedArrayUsingComparator:^NSComparisonResult (id _Nonnull obj1, id _Nonnull obj2) {
        return [obj2 compare:obj1];
    }];
    NSMutableArray<NSDictionary<NSString *, id> *> *crashLogArray = [NSMutableArray array];

    for (NSUInteger i = 0; i < crashLogFiles.count; i++) {
        NSData *data = [TikTokErrorHandler _loadCrashLog:[TikTokErrorHandler array:crashLogFiles objectAtIndex:i]];
        if (!data) {
            continue;
        }
        NSDictionary<NSString *, id> *tempCrashLog = [TikTokTypeUtility JSONObjectWithData:data
                                                                               options:kNilOptions
                                                                                 error:nil
                                                                                origin:@"TikTokErrorHandler"];
        NSArray *crashLogInfo = [tempCrashLog valueForKey:kTTSDKCrashInfo];
        NSString *crashStack = [crashLogInfo componentsJoinedByString:@"\n"];
        NSArray *crashSdkVersion = [[TikTokErrorHandler array:crashLogInfo objectAtIndex:0] componentsSeparatedByString:@": "];
        NSMutableDictionary<NSString *, id> *crashLog = [[NSMutableDictionary alloc] initWithDictionary:tempCrashLog];
        [crashLog setValue:crashStack forKey:kTTSDKCrashInfo];
        [crashLog setValue:[TikTokErrorHandler array:crashSdkVersion objectAtIndex:1] forKey:kTTSDKCrashSDKVeriosn];
        if (crashLog) {
            [TikTokErrorHandler array:crashLogArray addObject:crashLog];
        }
    }

    return [crashLogArray copy];
}

+ (nullable NSData *)_loadCrashLog:(NSString *)crashLog
{
    NSData *resultData = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [directoryPath stringByAppendingPathComponent:crashLog];
    BOOL exists = [fm fileExistsAtPath:path];
    if (exists) {
        resultData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    } else {
        resultData = nil;
    }
  return resultData;
}

+ (NSArray<NSString *> *)_getCrashLogFileNames:(NSArray<NSString *> *)files
{
    NSMutableArray<NSString *> *fileNames = [NSMutableArray array];

    for (NSString *fileName in files) {
        if ([fileName hasPrefix:@"crash-log_"] && [fileName hasSuffix:@".json"]) {
            [TikTokErrorHandler array:fileNames addObject:fileName];
        }
    }

    return fileNames;
}

+ (BOOL)_callstack:(NSArray<NSString *> *)callstack
    containsTTSDKInfo:(NSArray<NSString *> *)TTSDKInfo
{
    NSString *callStackString = [callstack componentsJoinedByString:@""];
    for (NSString *keyWord in TTSDKInfo) {
        if ([callStackString containsString:keyWord]) {
          return YES;
        }
    }

    return NO;
}

+ (nullable id)array:(NSArray *)files objectAtIndex:(NSUInteger)index
{
    if ([self arrayValue:files] && index < files.count) {
        return [files objectAtIndex:index];
    }

    return nil;
}

+ (void)array:(NSMutableArray *)array addObject:(id)object
{
    if (object && [array isKindOfClass:NSMutableArray.class]) {
        [array addObject:object];
    }
}

+ (NSArray *)arrayValue:(id)object
{
    return (NSArray *)[self _objectValue:object ofClass:[NSArray class]];
}

+ (id)_objectValue:(id)object ofClass:(Class)expectedClass
{
    return ([object isKindOfClass:expectedClass] ? object : nil);
}

+ (BOOL)isSDKCrashReport:(NSString *)report {
    int64_t beginAddress = -1;
    int64_t endAddress = -1;
    int crashThreadidx = -1;
    if (![TikTokErrorHandler getBeginAddress:&beginAddress EndAddress:&endAddress fromReport:report] ||
        ![TikTokErrorHandler getCrashThreadIndex:&crashThreadidx fromReport:report]) {
        return NO;
    }
    NSString *crashStackString = [TikTokErrorHandler getCrashStackStringOfIndex:crashThreadidx fromReport:report];
    if (!TTCheckValidString(crashStackString)) {
        return NO;
    }
    NSArray *lines = [crashStackString componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        if (![line containsString:@"0x"]) {
            continue;
        }
        int64_t address = [TikTokErrorHandler addressInLine:TTSafeString(line)];
        if (address > beginAddress && address < endAddress) {
            [[TikTokFactory getLogger] verbose:@"Found stack related to SDK: %@", line];
            return YES;
        }
    }
    return NO;
}

// MARK: - String Utils

+ (BOOL)getBeginAddress:(int64_t *)beginAddress EndAddress:(int64_t *)endAddress fromReport:(NSString*)report {
    NSString *rangeString = [TikTokErrorHandler getLineBeginWith:@"Address Range" fromReport:report];
    if (!TTCheckValidString(rangeString)) {
        return NO;
    }
    NSArray *addresses = [rangeString componentsSeparatedByString:@"**"];
    if (addresses.count > 2) {
        *beginAddress = [addresses[1] longLongValue];
        *endAddress = [addresses[2] longLongValue];
        return YES;
    }
    return NO;
}

+ (long long)getCrashTimetampFromReport:(NSString*)report {
    NSString *dateTimeString = [TikTokErrorHandler getLineBeginWith:@"Date/Time:" fromReport:report];
    long long timeInterval = -1;
    if (TTCheckValidString(dateTimeString)) {
        NSInteger startPos = @"Date/Time:           ".length;
        NSString *dateString = [dateTimeString substringFromIndex:startPos];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS ZZZ"];
        NSDate *date = [dateFormatter dateFromString:dateString];
        timeInterval = (long long)([date timeIntervalSince1970] * 1000);
    }
    return timeInterval;
}

+ (BOOL)getCrashThreadIndex:(int *)thread fromReport:(NSString*)report {
    NSString *triggerString = [TikTokErrorHandler getLineBeginWith:@"Triggered by Thread" fromReport:report];
    if (TTCheckValidString(triggerString)) {
        NSInteger startPos = @"Triggered by Thread: ".length;
        NSString *indexString = [triggerString substringFromIndex:startPos];
        int threadValue = [indexString intValue];
        *thread = threadValue;
        return YES;
    }
    return NO;
}

+ (NSString *)getCrashStackStringOfIndex:(int)crashThreadidx fromReport:(NSString*)report {
    NSString *startString = [NSString stringWithFormat:@"Thread %d", crashThreadidx];
    NSString *endString = @"\n\n";
    NSRange startRange = [report rangeOfString:startString];
    if (startRange.length == 0) {
        return @"";
    }
    NSString *stripHead = [report substringFromIndex:startRange.location];
    NSRange endRange = [stripHead rangeOfString:endString];
    if (endRange.length == 0) {
        return @"";
    }
    NSString *crashStack = [stripHead substringToIndex:endRange.location];
    return crashStack;
}

+ (NSString *)getLineBeginWith:(NSString *)begin fromReport:(NSString *)report {
    NSArray *lines = [report componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line hasPrefix:begin]) {
            return line;
        }
    }
    return @"";
}

+ (int64_t)addressInLine:(NSString *)line {
    NSArray *words = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *word in words) {
        if ([word hasPrefix:@"0x"]) {
            NSString *hexString = [word substringFromIndex:2];
            unsigned long long addressValue = strtoull([hexString UTF8String], NULL, 16);
            return (int64_t)addressValue;
        }
    }
    return 0;
}
@end
