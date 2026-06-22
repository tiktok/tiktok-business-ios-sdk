//
//  TTSDKCrashReportFilterDoctor.m
//
//  Created by Karl Stenerud on 2024-09-05.
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

#import "TTSDKCrashReportFilterDoctor.h"
#import "TTSDKCrashDoctor.h"
#import "TTSDKCrashReport.h"
#import "TTSDKCrashReportFields.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

@interface TTSDKCrashReportFilterDoctor ()

@end

@implementation TTSDKCrashReportFilterDoctor

+ (NSString *)diagnoseCrash:(NSDictionary *)crashReport
{
    return [[TTSDKCrashDoctor new] diagnoseCrash:crashReport];
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSMutableArray<id<TTSDKCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (TTSDKCrashReportDictionary *report in reports) {
        if ([report isKindOfClass:[TTSDKCrashReportDictionary class]] == NO) {
            TTSDKLOG_ERROR(@"Unexpected non-dictionary report: %@", report);
            continue;
        }

        NSString *diagnose = [[self class] diagnoseCrash:report.value];
        NSMutableDictionary *crashReport = [report.value mutableCopy];
        if (diagnose != nil) {
            if (crashReport[TTSDKCrashField_Crash] != nil) {
                NSMutableDictionary *crashDict = [crashReport[TTSDKCrashField_Crash] mutableCopy];
                crashDict[TTSDKCrashField_Diagnosis] = diagnose;
                crashReport[TTSDKCrashField_Crash] = crashDict;
            }
            if (crashReport[TTSDKCrashField_RecrashReport][TTSDKCrashField_Crash] != nil) {
                NSMutableDictionary *recrashReport = [crashReport[TTSDKCrashField_RecrashReport] mutableCopy];
                NSMutableDictionary *crashDict = [recrashReport[TTSDKCrashField_Crash] mutableCopy];
                crashDict[TTSDKCrashField_Diagnosis] = diagnose;
                recrashReport[TTSDKCrashField_Crash] = crashDict;
                crashReport[TTSDKCrashField_RecrashReport] = recrashReport;
            }
        }

        [filteredReports addObject:[TTSDKCrashReportDictionary reportWithValue:crashReport]];
    }

    ttsdkcrash_callCompletion(onCompletion, filteredReports, nil);
}

@end
