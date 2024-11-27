//
//  TTSDKCrashFilterSets.m
//
//  Created by Karl Stenerud on 2012-08-21.
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

#import "TTSDKCrashReportFilterSets.h"
#import "TTSDKCrashReportFields.h"
#import "TTSDKCrashReportFilterBasic.h"
#import "TTSDKCrashReportFilterGZip.h"
#import "TTSDKCrashReportFilterJSON.h"

@implementation TTSDKCrashFilterSets

+ (id<TTSDKCrashReportFilter>)appleFmtWithUserAndSystemData:(TTSDKAppleReportStyle)reportStyle compressed:(BOOL)compressed
{
    NSString *const kAppleReportName = @"Apple Report";
    NSString *const kUserSystemDataName = @"User & System Data";

    id<TTSDKCrashReportFilter> appleFilter = [[TTSDKCrashReportFilterAppleFmt alloc] initWithReportStyle:reportStyle];
    id<TTSDKCrashReportFilter> userSystemFilter = [self createUserSystemFilterPipeline];

    id<TTSDKCrashReportFilter> combineFilter = [[TTSDKCrashReportFilterCombine alloc]
        initWithFilters:@{ kAppleReportName : appleFilter, kUserSystemDataName : userSystemFilter }];

    id<TTSDKCrashReportFilter> concatenateFilter =
        [[TTSDKCrashReportFilterConcatenate alloc] initWithSeparatorFmt:@"\n\n-------- %@ --------\n\n"
                                                                keys:@[ kAppleReportName, kUserSystemDataName ]];

    NSMutableArray *mainFilters = [NSMutableArray arrayWithObjects:combineFilter, concatenateFilter, nil];

    if (compressed) {
        [mainFilters addObject:[TTSDKCrashReportFilterStringToData new]];
        [mainFilters addObject:[[TTSDKCrashReportFilterGZipCompress alloc] initWithCompressionLevel:-1]];
    }

    return [[TTSDKCrashReportFilterPipeline alloc] initWithFilters:mainFilters];
}

+ (id<TTSDKCrashReportFilter>)createUserSystemFilterPipeline
{
    return [[TTSDKCrashReportFilterPipeline alloc] initWithFilters:@[
        [[TTSDKCrashReportFilterSubset alloc] initWithKeys:@[ TTSDKCrashField_System, TTSDKCrashField_User ]],
        [[TTSDKCrashReportFilterJSONEncode alloc] initWithOptions:TTSDKJSONEncodeOptionPretty | TTSDKJSONEncodeOptionSorted],
        [TTSDKCrashReportFilterDataToString new]
    ]];
}

@end
