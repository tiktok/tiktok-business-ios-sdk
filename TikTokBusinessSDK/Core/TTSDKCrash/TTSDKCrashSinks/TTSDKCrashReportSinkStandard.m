//
//  TTSDKCrashReportSinkStandard.m
//
//  Created by Karl Stenerud on 2012-02-18.
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

#import "TTSDKCrashReportSinkStandard.h"

#import "TTSDKCrashReport.h"
#import "TTSDKGZipHelper.h"
#import "TTSDKHTTPMultipartPostBody.h"
#import "TTSDKHTTPRequestSender.h"
#import "TTSDKJSONCodecObjC.h"
#import "TTSDKReachabilityTTSDKCrash.h"
#import "TikTokTypeUtility.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

@interface TTSDKCrashReportSinkStandard ()

@property(nonatomic, readwrite, strong) NSURL *url;

@property(nonatomic, readwrite, strong) TTSDKReachableOperationTTSDKCrash *reachableOperation;

@end

@implementation TTSDKCrashReportSinkStandard

- (instancetype)initWithURL:(NSURL *)url
{
    if ((self = [super init])) {
        _url = url;
    }
    return self;
}

- (id<TTSDKCrashReportFilter>)defaultCrashReportFilterSet
{
    return self;
}

- (void)filterReports:(NSArray<id<TTSDKCrashReport>> *)reports onCompletion:(TTSDKCrashReportFilterCompletion)onCompletion
{
    NSError *error = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15];
    TTSDKHTTPMultipartPostBody *body = [TTSDKHTTPMultipartPostBody body];
    NSMutableArray *jsonArray = [NSMutableArray array];
    for (id<TTSDKCrashReport> report in reports) {
        if ([report isKindOfClass:[TTSDKCrashReportDictionary class]]) {
            TTSDKCrashReportDictionary *dReport = report;
            if (dReport.value != nil) {
                [jsonArray addObject:dReport.value];
            }
        } else if ([report isKindOfClass:[TTSDKCrashReportString class]]) {
            TTSDKCrashReportString *sReport = report;
            if (sReport.value != nil) {
                [jsonArray addObject:sReport.value];
            }
        } else {
            TTSDKLOG_ERROR(@"Unexpected non-dictionary/non-string report: %@", report);
        }
    }
    NSData *jsonData = [TTSDKJSONCodec encode:jsonArray options:TTSDKJSONEncodeOptionSorted error:&error];
    jsonData = [TTSDKJSONCodec encode:@{@"batch":jsonArray} options:TTSDKJSONEncodeOptionSorted error:&error];
    if (jsonData == nil) {
        ttsdkcrash_callCompletion(onCompletion, reports, error);
        return;
    }

    [body appendData:jsonData name:@"reports" contentType:@"application/json" filename:@"reports.json"];
    // TODO: Disabled gzip compression until support is added server side,
    // and I've fixed a bug in appendUTF8String.
    //    [body appendUTF8String:@"json"
    //                      name:@"encoding"
    //               contentType:@"string"
    //                  filename:nil];

    request.HTTPMethod = @"POST";
    request.HTTPBody = [body data];
    [request setValue:body.contentType forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"TTSDKCrashReporter" forHTTPHeaderField:@"User-Agent"];

    //    [request setHTTPBody:[[body data] gzippedWithError:nil]];
    //    [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];

    self.reachableOperation = [TTSDKReachableOperationTTSDKCrash
        operationWithHost:[self.url host]
                allowWWAN:YES
                    block:^{
                        [[TTSDKHTTPRequestSender sender] sendRequest:request
                            onSuccess:^(__unused NSHTTPURLResponse *response, __unused NSData *data) {
                                ttsdkcrash_callCompletion(onCompletion, reports, nil);
                            }
                            onFailure:^(NSHTTPURLResponse *response, NSData *data) {
                                NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                ttsdkcrash_callCompletion(
                                    onCompletion, reports,
                                    [NSError
                                        errorWithDomain:[[self class] description]
                                                   code:response.statusCode
                                               userInfo:[NSDictionary dictionaryWithObject:text
                                                                                    forKey:NSLocalizedDescriptionKey]]);
                            }
                            onError:^(NSError *error2) {
                                ttsdkcrash_callCompletion(onCompletion, reports, error2);
                            }];
                    }];
}

@end
