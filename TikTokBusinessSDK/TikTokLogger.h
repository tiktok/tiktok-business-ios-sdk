//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {

    TikTokLogLevelVerbose = 1,
    TikTokLogLevelDebug = 2,
    TikTokLogLevelInfo = 3,
    TikTokLogLevelWarn = 4,
    TikTokLogLevelError = 5,
    TikTokLogLevelAssert = 6,
    TikTokLogLevelSuppress = 7

} TikTokLogLevel;

/**
 * @brief Used to log helpful messages during SDK lifecycle
*/
@protocol TikTokLogger

- (void)setLogLevel: (TikTokLogLevel)logLevel;
- (void)lockLogLevel;
- (void)verbose: (nonnull NSString *)message, ...;
- (void)debug: (nonnull NSString *)message, ...;
- (void)info: (nonnull NSString *)message, ...;
- (void)warn: (nonnull NSString *)message, ...;
- (void)warnInProduction: (nonnull NSString *)message, ...;
- (void)error: (nonnull NSString *)message, ...;
- (void)assert: (nonnull NSString *)message, ...;

@end

@interface TikTokLogger : NSObject<TikTokLogger>

+ (TikTokLogLevel)logLevelFromString: (nonnull NSString *)logLevelString;

@end

NS_ASSUME_NONNULL_END
