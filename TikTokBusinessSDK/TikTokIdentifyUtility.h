//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokIdentifyUtility : NSObject

@property (nonatomic, strong, nullable) NSString *externalID;
@property (nonatomic, strong, nullable) NSString *externalUserName;
@property (nonatomic, strong, nullable) NSString *phoneNumber;
@property (nonatomic, strong, nullable) NSString *email;
@property (nonatomic, assign) BOOL isIdentified;

+ (instancetype)sharedInstance;

- (NSString *)getOrGenerateAnonymousID;

- (NSString *)generateNewAnonymousID;

- (void)setUserInfoWithExternalID:(nullable NSString *)externalID
                 externalUserName:(nullable NSString *)externalUserName
                      phoneNumber:(nullable NSString *)phoneNumber
                            email:(nullable NSString *)email
                           origin:(nullable NSString *)origin;

- (NSDictionary *)getUserInfoDictionary;

- (void)resetUserInfo;

@end

NS_ASSUME_NONNULL_END
