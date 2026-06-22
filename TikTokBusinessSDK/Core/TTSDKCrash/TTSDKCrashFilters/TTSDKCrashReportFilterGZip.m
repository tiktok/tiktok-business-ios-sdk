//
//  TTSDKCrashReportFilterGZip.m
//
//  Created by Karl Stenerud on 2012-05-10.
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

#import "TTSDKCrashReportFilterGZip.h"
#import "TTSDKCrashReport.h"
#import "TTSDKGZipHelper.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

@interface TTSDKCrashReportFilterGZipCompress ()

@property(nonatomic, readwrite, assign) NSInteger compressionLevel;

@end

@implementation TTSDKCrashReportFilterGZipCompress

- (instancetype)initWithCompressionLevel:(NSInteger)compressionLevel
{
    if ((self = [super init])) {
        _compressionLevel = compressionLevel;
    }
    return self;
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSMutableArray<id<TTSDKCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (TTSDKCrashReportData *report in reports) {
        if ([report isKindOfClass:[TTSDKCrashReportData class]] == NO) {
            TTSDKLOG_ERROR(@"Unexpected non-data report: %@", report);
            continue;
        }

        NSError *error = nil;
        NSData *compressedData = [TTSDKGZipHelper gzippedData:report.value
                                          compressionLevel:(int)self.compressionLevel
                                                     error:&error];
        if (compressedData == nil) {
            ttsdkcrash_callCompletion(onCompletion, filteredReports, error);
            return;
        } else {
            [filteredReports addObject:[TTSDKCrashReportData reportWithValue:compressedData]];
        }
    }

    ttsdkcrash_callCompletion(onCompletion, filteredReports, nil);
}

@end

@implementation TTSDKCrashReportFilterGZipDecompress

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSMutableArray<id<TTSDKCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (TTSDKCrashReportData *report in reports) {
        if ([report isKindOfClass:[TTSDKCrashReportData class]] == NO) {
            TTSDKLOG_ERROR(@"Unexpected non-data report: %@", report);
            continue;
        }

        NSError *error = nil;
        NSData *decompressedData = [TTSDKGZipHelper gunzippedData:report.value error:&error];
        if (decompressedData == nil) {
            ttsdkcrash_callCompletion(onCompletion, filteredReports, error);
            return;
        } else {
            [filteredReports addObject:[TTSDKCrashReportData reportWithValue:decompressedData]];
        }
    }

    ttsdkcrash_callCompletion(onCompletion, filteredReports, nil);
}

@end
