//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokErrorHandler.h"
#import "TikTokBusiness.h"
#import "TikTokFactory.h"
#import "TikTokTypeUtility.h"
#import "TikTokRequestHandler.h"
#import "TikTokBusinessSDKMacros.h"

#define TTSDK_CRASH_PATH_NAME @"monitoring"
#define TTSDK_KEYWORDS  [NSArray arrayWithObjects: @"TikTokBusinessSDK",nil]

static NSString *directoryPath;

NSString *const kTTSDKCrashInfo = @"crash_info";
NSString *const kTTSDKCrashReason = @"Exception Reason";
NSString *const kTTSDKCrashName = @"Exception Name";
NSString *const kTTSDKCrashReportID = @"crash_log_id";
NSString *const kTTSDKCrashSDKVeriosn = @"crash_sdk_version";
NSString *const kTTSDKCrashTimestamp = @"timestamp";
NSString *const kTTSDKVersion = @"TikTok SDK Version";

@implementation TikTokErrorHandler

static void handleUncaughtException(NSException *exception)
{
    [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([TikTokErrorHandler class]) message:@"Uncaught Exception" exception:exception];

    NSArray<NSString *> *callStack = [exception callStackSymbols];
    if([TikTokErrorHandler _callstack:callStack containsTTSDKInfo:TTSDK_KEYWORDS]) {
        NSMutableArray<NSString *> *crash_info = [[NSMutableArray alloc]init];
        [crash_info addObject:[NSString stringWithFormat:@"%@: %@", kTTSDKVersion, SDK_VERSION]];
        [crash_info addObject:[NSString stringWithFormat:@"%@: %@", kTTSDKCrashName, [exception name]]];
        [crash_info addObject:[NSString stringWithFormat:@"%@: %@", kTTSDKCrashReason, [exception reason]]];
        [crash_info addObjectsFromArray:callStack];

        NSString *crashReportId = [[NSUUID UUID] UUIDString];
        NSString *currentTimestamp = [NSString stringWithFormat:@"%.0lf", [[NSDate date] timeIntervalSince1970]];

        directoryPath = [TikTokErrorHandler initDirectPath];
        NSString *path = [TikTokErrorHandler getCrashReportPathWithCrashReportId:crashReportId currentTimestamp:currentTimestamp];
        NSMutableDictionary *crashReport =  [[NSMutableDictionary alloc] init];
        [TikTokTypeUtility dictionary:crashReport setObject:crash_info forKey:kTTSDKCrashInfo];
        [TikTokTypeUtility dictionary:crashReport setObject:crashReportId forKey:kTTSDKCrashReportID];
        [TikTokTypeUtility dictionary:crashReport setObject:currentTimestamp forKey:kTTSDKCrashTimestamp];

        NSData *crashReportData = [TikTokTypeUtility dataWithJSONObject:crashReport options:NSJSONWritingPrettyPrinted error:nil origin:@"TikTokErrorHandler"];
        [crashReportData writeToFile:path atomically:YES];
    }

    [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([TikTokErrorHandler class]) message:@"Uncaught Exception" exception:exception];
}

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

NSUncaughtExceptionHandler *handleUncaughtExceptionPointer = &handleUncaughtException;

@end
