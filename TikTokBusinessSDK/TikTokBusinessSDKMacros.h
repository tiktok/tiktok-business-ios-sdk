//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

#define SDK_VERSION @"1.6.0"

#define TT_CONFIG_PATH @"/api/v1/app_sdk/config"
#define TT_CACHE_CONFIG_PATH @"/api/v1/app_sdk/cache/config"
#define TT_BATCH_EVENT_PATH @"/api/v1/app_sdk/batch"
#define TT_MONITOR_EVENT_PATH @"/api/v1/app_sdk/monitor"
#define TT_FETCH_DDL_PATH @"/api/v1/app_sdk/ddl"

#ifndef TT_isEmptyString
FOUNDATION_EXPORT BOOL TT_isEmptyString(id param);
#endif

#ifndef TT_isEmptyArray
FOUNDATION_EXPORT BOOL TT_isEmptyArray(id param);
#endif

#ifndef TT_isEmptyDictionary
FOUNDATION_EXPORT BOOL TT_isEmptyDictionary(id param);
#endif

#define TTSafeString(__string)                        ((__string && [__string isKindOfClass:[NSString class]]) ? __string :@"")

#define TTSafeDictionary(__aDictionary)               ((__aDictionary && [__aDictionary isKindOfClass:[NSDictionary class]]) ? __aDictionary :@{})

#ifndef tt_weakify
#if __has_feature(objc_arc)
#define tt_weakify(object) __weak __typeof__(object) weak##object = object;
#else
#define tt_weakify(object) __block __typeof__(object) block##object = object;
#endif
#endif
#ifndef tt_strongify
#if __has_feature(objc_arc)
#define tt_strongify(object) __typeof__(object) object = weak##object;
#else
#define tt_strongify(object) __typeof__(object) object = block##object;
#endif
#endif
