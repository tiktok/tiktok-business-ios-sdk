//
//  TTSDKCrashReportSinkStandard.h
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

#import "TTSDKCrashReportFilter.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Sends crash reports to an HTTP server.
 *
 * Input: NSDictionary
 * Output: Same as input (passthrough)
 */
NS_SWIFT_NAME(CrashReportSinkStandard)
@interface TTSDKCrashReportSinkStandard : NSObject <TTSDKCrashReportFilter>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/** Constructor.
 *
 * @param url The URL to connect to.
 */
- (instancetype)initWithURL:(NSURL *)url;

@property(nonatomic, readonly) id<TTSDKCrashReportFilter> defaultCrashReportFilterSet;

@end

NS_ASSUME_NONNULL_END
