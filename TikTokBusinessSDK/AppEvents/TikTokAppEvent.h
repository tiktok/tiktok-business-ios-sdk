//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokAppEvent : NSObject<NSCopying, NSSecureCoding>
/**
 * @brief Name of event
 */
@property (nonatomic, copy, nonnull) NSString *eventName;

/**
 * @brief Timestamp
 */
@property (nonatomic, nonnull) NSString *timestamp;

/**
 * @brief Additional properties in the form of NSDictionary
 */
@property (nonatomic) NSDictionary *properties;

/**
 * @brief Type of event ('track' or 'identify')
 */
@property (nonatomic, nonnull) NSString *type;

/**
 * @brief AnonymousID at the time event is tracked.
 */
@property (nonatomic) NSString *anonymousID;

/**
 * @brief User info at the time event is tracked. If not logged in, will be nil
 */
@property (nonatomic, nullable) NSDictionary *userInfo;

/**
 * @brief Event ID defined by advertisers.
 */
@property (nonatomic) NSString *eventID;

- (instancetype)initWithEventName: (NSString *)eventName;

- (instancetype)initWithEventName: (NSString *)eventName
                         withType: (NSString *)type;

- (instancetype)initWithEventName: (NSString *)eventName
                   withProperties: (NSDictionary *)properties;

- (instancetype)initWithEventName: (NSString *)eventName
                   withProperties: (NSDictionary *)properties
                         withType: (NSString *)type;

- (instancetype)initWithEventName: (NSString *)eventName
                   withProperties: (NSDictionary *)properties
                         withType: (NSString *)type
                      withEventId: (NSString *)eventID;
@end

NS_ASSUME_NONNULL_END
