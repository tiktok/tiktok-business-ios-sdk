//
//  TikTokBusinessSDKMacros.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2022/11/3.
//  Copyright © 2022 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokBusinessSDKMacros.h"

BOOL TT_isEmptyString(id param)
{
    if (!param) {
        return YES;
    }
    if ([param isKindOfClass:[NSString class]]) {
        NSString *str = param;
        return str.length == 0;
    }
    
    NSCAssert(NO, @"TT_isEmptyString: param %@ is not NSString", param);
    return YES;
}

BOOL TT_isEmptyArray(id param)
{
    if (!param) {
        return YES;
    }
    if ([param isKindOfClass:[NSArray class]]) {
        NSArray *array = param;
        return array.count == 0;
    }
    
    NSCAssert(NO, @"TT_isEmptyArray: param %@ is not NSArray", param);
    return YES;
}

BOOL TT_isEmptyDictionary(id param)
{
    if (!param) {
        return YES;
    }
    if ([param isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = param;
        return dict.count == 0;
    }
    
    NSCAssert(NO, @"TT_isEmptyDictionary: param %@ is not NSDictionary", param);
    return YES;
}
