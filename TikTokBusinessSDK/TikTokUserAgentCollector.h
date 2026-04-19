//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_TV
#import <WebKit/WKWebView.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief This class is used to fetch User Agent from WebKit
*/
@interface TikTokUserAgentCollector : NSObject

@property (nonatomic, copy, readwrite) NSString *userAgent;

+ (TikTokUserAgentCollector *)singleton;

/**
 * @brief Handles asynchronous Javascript call to the WebKit browser
*/
- (void)loadUserAgentWithCompletion:(void(^)(NSString * _Nullable userAgent))completion;
- (void)setCustomUserAgent:(NSString *)userAgent;

@end

NS_ASSUME_NONNULL_END
