//
//  TTSDKCrashReportStore.m
//
//  Created by Nikolay Volosatov on 2024-08-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "TTSDKCrashReportStore.h"

#import "TTSDKCrash+Private.h"
#import "TTSDKCrashConfiguration+Private.h"
#import "TTSDKCrashReport.h"
#import "TTSDKCrashReportFields.h"
#import "TTSDKCrashReportFilter.h"
#import "TTSDKCrashReportStoreC.h"
#import "TTSDKJSONCodecObjC.h"
#import "TTSDKNSErrorHelper.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

@implementation TTSDKCrashReportStore {
    TTSDKCrashReportStoreCConfiguration _cConfig;
}

+ (NSString *)defaultInstallSubfolder
{
    return @TTSDKCRS_DEFAULT_REPORTS_FOLDER;
}

+ (instancetype)defaultStoreWithError:(NSError **)error
{
    return [TTSDKCrashReportStore storeWithConfiguration:nil error:error];
}

+ (instancetype)storeWithConfiguration:(TTSDKCrashReportStoreConfiguration *)configuration error:(NSError **)error
{
    return [[TTSDKCrashReportStore alloc] initWithConfiguration:configuration error:error];
}

- (nullable instancetype)initWithConfiguration:(TTSDKCrashReportStoreConfiguration *)configuration error:(NSError **)error
{
    self = [super init];
    if (self != nil) {
        _cConfig = [(configuration ?: [TTSDKCrashReportStoreConfiguration new]) toCConfiguration];
        _reportCleanupPolicy = TTSDKCrashReportCleanupPolicyAlways;

        ttsdkcrs_initialize(&_cConfig);
    }
    return self;
}

- (void)dealloc
{
    TTSDKCrashReportStoreCConfiguration_Release(&_cConfig);
}

- (NSInteger)reportCount
{
    return ttsdkcrs_getReportCount(&_cConfig);
}

- (void)sendAllReportsWithCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSArray *reports = [self allReports];

    TTSDKLOG_INFO(@"Sending %d crash reports", [reports count]);

    __weak __typeof(self) weakSelf = self;
    [self sendReports:reports
         onCompletion:^(NSArray *filteredReports, NSError *error) {
             TTSDKLOG_DEBUG(@"Process finished");
             if (error != nil) {
                 TTSDKLOG_ERROR(@"Failed to send reports: %@", error);
             }
             if ((self.reportCleanupPolicy == TTSDKCrashReportCleanupPolicyOnSuccess && error == nil) ||
                 self.reportCleanupPolicy == TTSDKCrashReportCleanupPolicyAlways) {
                 [weakSelf deleteAllReports];
             }
             ttsdkcrash_callCompletion(onCompletion, filteredReports, error);
         }];
}

- (void)deleteAllReports
{
    ttsdkcrs_deleteAllReports(&_cConfig);
}

- (void)deleteReportWithID:(int64_t)reportID
{
    ttsdkcrs_deleteReportWithID(reportID, &_cConfig);
}

#pragma mark - Private API

- (void)sendReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    if ([reports count] == 0) {
        ttsdkcrash_callCompletion(onCompletion, reports, nil);
        return;
    }

    if (self.sink == nil) {
        ttsdkcrash_callCompletion(onCompletion, reports,
                               [TTSDKNSErrorHelper errorWithDomain:[[self class] description]
                                                           code:0
                                                    description:@"No sink set. Crash reports not sent."]);
        return;
    }
    [self.sink filterReports:reports
                onCompletion:^(NSArray *filteredReports, NSError *error) {
                    ttsdkcrash_callCompletion(onCompletion, filteredReports, error);
                }];
}

- (NSData *)loadCrashReportJSONWithID:(int64_t)reportID
{
    char *report = ttsdkcrs_readReport(reportID, &_cConfig);
    if (report != NULL) {
        return [NSData dataWithBytesNoCopy:report length:strlen(report) freeWhenDone:YES];
    }
    return nil;
}

- (NSArray<NSNumber *> *)reportIDs
{
    int reportCount = ttsdkcrs_getReportCount(&_cConfig);
    int64_t reportIDsC[reportCount];
    reportCount = ttsdkcrs_getReportIDs(reportIDsC, reportCount, &_cConfig);
    NSMutableArray *reportIDs = [NSMutableArray arrayWithCapacity:(NSUInteger)reportCount];
    for (int i = 0; i < reportCount; i++) {
        [reportIDs addObject:[NSNumber numberWithLongLong:reportIDsC[i]]];
    }
    return [reportIDs copy];
}

- (TTSDKCrashReportDictionary *)reportForID:(int64_t)reportID
{
    NSData *jsonData = [self loadCrashReportJSONWithID:reportID];
    if (jsonData == nil) {
        return nil;
    }

    NSError *error = nil;
    NSMutableDictionary *crashReport =
        [TTSDKJSONCodec decode:jsonData
                    options:TTSDKJSONDecodeOptionIgnoreNullInArray | TTSDKJSONDecodeOptionIgnoreNullInObject |
                            TTSDKJSONDecodeOptionKeepPartialObject
                      error:&error];
    if (error != nil) {
        TTSDKLOG_ERROR(@"Encountered error loading crash report %" PRIx64 ": %@", reportID, error);
    }
    if (crashReport == nil) {
        TTSDKLOG_ERROR(@"Could not load crash report");
        return nil;
    }

    return [TTSDKCrashReportDictionary reportWithValue:crashReport];
}

- (NSArray<TTSDKCrashReportDictionary *> *)allReports
{
    int reportCount = ttsdkcrs_getReportCount(&_cConfig);
    int64_t reportIDs[reportCount];
    reportCount = ttsdkcrs_getReportIDs(reportIDs, reportCount, &_cConfig);
    NSMutableArray<TTSDKCrashReportDictionary *> *reports = [NSMutableArray arrayWithCapacity:(NSUInteger)reportCount];
    for (int i = 0; i < reportCount; i++) {
        TTSDKCrashReportDictionary *report = [self reportForID:reportIDs[i]];
        if (report != nil) {
            [reports addObject:report];
        }
    }

    return reports;
}

@end
