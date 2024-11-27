//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokErrorHandler : NSObject

/**
 * @brief Error handling with exception
 */
+ (void)handleErrorWithOrigin:(NSString *)origin
                      message:(NSString *)message
                    exception:(NSException *)exception;
/**
 * @brief Error handling without exception
 */
+ (void)handleErrorWithOrigin:(NSString *)origin
                      message:(NSString *)message;

/**
 * @brief Load crash logs
 */
+ (NSDictionary<NSString *, id> *)getLastestCrashLog;

/**
 * @brief Clear crash logs
 */
+ (void)clearCrashReportFiles;

+ (BOOL)isSDKCrashReport:(NSString *)report;

+ (long long)getCrashTimetampFromReport:(NSString*)report;

@end

NS_ASSUME_NONNULL_END
