//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

#define SDK_VERSION @"1.3.5"

#define TT_CONFIG_PATH @"/api/v1/app_sdk/config"
#define TT_BATCH_EVENT_PATH @"/api/v1/app_sdk/batch"
#define TT_MONITOR_EVENT_PATH @"/api/v1/app_sdk/monitor"

#ifndef TT_isEmptyString
FOUNDATION_EXPORT BOOL TT_isEmptyString(id param);
#endif

#ifndef TT_isEmptyArray
FOUNDATION_EXPORT BOOL TT_isEmptyArray(id param);
#endif

#ifndef TT_isEmptyDictionary
FOUNDATION_EXPORT BOOL TT_isEmptyDictionary(id param);
#endif

// - MARK: UserDefaults
FOUNDATION_EXPORT NSString * const TTUserDefaultsKey_firstLaunchTime;

#define TTSafeString(__string)                        ((__string && [__string isKindOfClass:[NSString class]]) ? __string :@"")

#define TTSafeDictionary(__aDictionary)               ((__aDictionary && [__aDictionary isKindOfClass:[NSDictionary class]]) ? __aDictionary :@{})
