//
//  TikTokDefaults.m
//  TikTokBusinessSDK
//
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokDefaults.h"

static NSString *const kTikTokDefaultsSuiteName = @"com.tiktok.business.sdk";

@implementation TikTokDefaults

+ (NSUserDefaults *)storage {
    static NSUserDefaults *_storage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _storage = [[NSUserDefaults alloc] initWithSuiteName:kTikTokDefaultsSuiteName];
        if (_storage == nil) {
            _storage = [NSUserDefaults standardUserDefaults];
        }
    });
    return _storage;
}

@end
