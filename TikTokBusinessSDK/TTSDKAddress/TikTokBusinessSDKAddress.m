//
//  TikTokBusinessSDKAddress.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 9/26/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokBusinessSDKAddress.h"

extern void * TikTokBusinessSDKFuncBeginAddress(void);
extern void * TikTokBusinessSDKFuncEndAddress(void);

@implementation TikTokBusinessSDKAddress

+ (int64_t)beginAddress {
    return (int64_t)TikTokBusinessSDKFuncBeginAddress();
}

+ (int64_t)endAddress {
    return (int64_t)TikTokBusinessSDKFuncEndAddress();
}

@end
