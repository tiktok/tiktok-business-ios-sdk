//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

/** VALID CHECKING**/
#define TTCheckValidString(__string)                ((BOOL)(__string && [__string isKindOfClass:[NSString class]] && [__string length]))
#define TTCheckValidNumber(__aNumber)               ((BOOL)(__aNumber && [__aNumber isKindOfClass:[NSNumber class]]))
#define TTCheckValidArray(__aArray)                 ((BOOL)(__aArray && [__aArray isKindOfClass:[NSArray class]] && [__aArray count]))
#define TTCheckValidDictionary(__aDictionary)       ((BOOL)(__aDictionary && [__aDictionary isKindOfClass:[NSDictionary class]] && [__aDictionary count]))
#define TTCheckValidDate(__aDate)                   ((BOOL)(__aDate && [__aDate isKindOfClass:[NSDate class]]))
#define TTCheckValidData(__aData)                   ((BOOL)(__aData && [__aData isKindOfClass:[NSData class]]))

NS_ASSUME_NONNULL_BEGIN

@interface TikTokTypeUtility : NSObject

/**
 * @brief Returns the provided object if it is non-null
 */
+ (nullable id)objectValue:(id)object;

/**
 * @brief Safety wrapper around Foundation's NSJSONSerialization:dataWithJSONObject:options:error:
 */
+ (nullable NSData *)dataWithJSONObject:(id)obj
                                options:(NSJSONWritingOptions)opt
                                  error:(NSError **)error
                                 origin:(NSString *)origin;

/**
 * @brief Safety wrapper around Foundation's NSJSONSerialization:JSONObjectWithData:options:error:
 */
+ (nullable id)JSONObjectWithData:(NSData *)data
                          options:(NSJSONReadingOptions)opt
                            error:(NSError **)error
                           origin:(NSString *)origin;

/**
 * @brief Sha256 hash for input
 */
+ (nullable NSString *)toSha256: (nullable NSObject*)input
                         origin:(nullable NSString *)origin;

+ (NSDictionary *)dictionaryValue:(id)object;

/**
 * @brief  Sets an object for a key in a mutable dictionary if both object and key are not nil.
 */
+ (void)dictionary:(NSMutableDictionary *)dictionary
         setObject:(nullable id)object
            forKey:(nullable id<NSCopying>)key;

/**
 * @brief  Match a string with defined regex pattern and return the matched part.
 */
+ (NSString *)matchString:(NSString *)inputString withRegex:(NSString *)pattern;

/**
 * @brief  Match the middle part of the string starting from startString (include) to endString (exclude).
 */

+ (NSString *)partialString:(NSString *)string fromStart:(NSString *)startString toEnd:(NSString *)endString;

@end

NS_ASSUME_NONNULL_END
