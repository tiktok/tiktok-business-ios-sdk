//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokUserAgentCollector.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokTypeUtility.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

@interface TikTokUserAgentCollector()

@property (nonatomic, strong, readwrite) WKWebView *webView;
@property (nonatomic, assign) BOOL updatedUa;

@end

@implementation TikTokUserAgentCollector

+ (TikTokUserAgentCollector *)singleton
{
    static TikTokUserAgentCollector *collector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        collector = [TikTokUserAgentCollector new];
    });
    return collector;
}

- (instancetype)init
{
    self = [super init];
    if(self) {
        self.userAgent = [[TikTokDefaults storage] objectForKey:TikTokDefaultsKeyUserAgent];
        self.updatedUa = NO;
    }
    return self;
}

- (void)loadUserAgentWithCompletion:(void (^)(NSString * _Nullable))completion
{
    if (!self.updatedUa && !TTCheckValidString(self.userAgent)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.webView) {
                @try {
                    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
                } @catch (NSException *exception) {
                } @finally {
                }
            }
            [self _update];
        });
    }
    if (completion) {
        completion(self.userAgent);
    }
}

- (void)_update {
    if (!self.webView) {
        return;
    }
    tt_weakify(self)
    [self.webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        tt_strongify(self)
        if (!TTCheckValidString(result)) {
            // Don't replace the existing value if fetched nil.
            return;
        }
        self.userAgent = result;
        self.updatedUa = YES;
        if (TTCheckValidString(result)) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSUserDefaults *userDefaults = [TikTokDefaults storage];
                [userDefaults setObject:result forKey:TikTokDefaultsKeyUserAgent];
                [userDefaults synchronize];
            });
        }
    }];
}

- (void)setCustomUserAgent:(NSString *)userAgent
{
    _userAgent = userAgent;
    self.updatedUa = YES;
    if (TTCheckValidString(userAgent)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSUserDefaults *userDefaults = [TikTokDefaults storage];
            [userDefaults setObject:userAgent forKey:TikTokDefaultsKeyUserAgent];
            [userDefaults synchronize];
        });
    }
}

@end
