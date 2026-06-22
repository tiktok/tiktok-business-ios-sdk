//
//  TTSDKCrashReportFilterStringify.m
//  TTSDKCrash
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

#import "TTSDKCrashReportFilterStringify.h"
#import "TTSDKCrashReport.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

@implementation TTSDKCrashReportFilterStringify

- (NSString *)stringifyReport:(id<TTSDKCrashReport>)report
{
    if ([report isKindOfClass:[TTSDKCrashReportString class]]) {
        return ((TTSDKCrashReportString *)report).value;
    }
    if ([report isKindOfClass:[TTSDKCrashReportData class]]) {
        NSData *value = ((TTSDKCrashReportData *)report).value;
        return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
    }
    if ([report isKindOfClass:[TTSDKCrashReportDictionary class]]) {
        NSDictionary *value = ((TTSDKCrashReportDictionary *)report).value;
        if ([NSJSONSerialization isValidJSONObject:value]) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
            return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        return [NSString stringWithFormat:@"%@", value];
    }
    return [report description] ?: @"Unknown";
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSMutableArray<id<TTSDKCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (id<TTSDKCrashReport> report in reports) {
        NSString *reportString = [self stringifyReport:report];
        [filteredReports addObject:[TTSDKCrashReportString reportWithValue:reportString]];
    }

    ttsdkcrash_callCompletion(onCompletion, filteredReports, nil);
}

@end
