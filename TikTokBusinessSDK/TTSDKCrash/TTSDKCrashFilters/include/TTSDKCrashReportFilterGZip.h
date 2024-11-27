//
//  TTSDKCrashReportFilterGZip.h
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

#import "TTSDKCrashReportFilter.h"

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An enumeration defining the levels of Gzip compression for crash reports.
 *
 * Compression levels range from 0 to 9, where:
 * - 0: No compression.
 * - 9: Best compression.
 * - -1: Default compression level.
 *
 * You can initialize this with any integer value between 0 and 9.
 */
typedef NSInteger TTSDKCrashReportCompressionLevel NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(CrashReportCompressionLevel);
/** No compression level. */
static TTSDKCrashReportCompressionLevel const TTSDKCrashReportCompressionLevelNone = 0;
/** Best compression level. */
static TTSDKCrashReportCompressionLevel const TTSDKCrashReportCompressionLevelBest = 9;
/** Default compression level. */
static TTSDKCrashReportCompressionLevel const TTSDKCrashReportCompressionLevelDefault = -1;

/**
 * Gzip compresses reports.
 *
 * Input: NSData
 * Output: NSData
 */
NS_SWIFT_NAME(CrashReportFilterGZipCompress)
@interface TTSDKCrashReportFilterGZipCompress : NSObject <TTSDKCrashReportFilter>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/** Initializer.
 *
 * @param compressionLevel Compression level for Gzip compression. It can be
 *                         one of the following `TTSDKCrashReportCompressionLevel` values:
 *                         - `TTSDKCrashReportCompressionLevelNone` (0): No compression.
 *                         - `TTSDKCrashReportCompressionLevelBest` (9): Best compression.
 *                         - `TTSDKCrashReportCompressionLevelDefault` (-1): Default compression level.
 *                         The compression level can be any integer value between 0 and 9.
 */
- (instancetype)initWithCompressionLevel:(TTSDKCrashReportCompressionLevel)compressionLevel;

@end

/** Gzip decompresses reports.
 *
 * Input: NSData
 * Output: NSData
 */
NS_SWIFT_NAME(CrashReportFilterGZipDecompress)
@interface TTSDKCrashReportFilterGZipDecompress : NSObject <TTSDKCrashReportFilter>

@end

NS_ASSUME_NONNULL_END
