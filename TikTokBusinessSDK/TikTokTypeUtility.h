//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

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

@end

NS_ASSUME_NONNULL_END
