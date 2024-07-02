//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokIdentifyUtility.h"
#import "TikTokTypeUtility.h"

@implementation TikTokIdentifyUtility

+ (instancetype)sharedInstance {
    static TikTokIdentifyUtility *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[TikTokIdentifyUtility alloc] init];
    });
    return _shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _phoneNumber = nil;
        _email = nil;
        _externalID = nil;
        _isIdentified = NO;
        _externalUserName = nil;
    }
    return self;
}

- (NSString *)getOrGenerateAnonymousID
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *anonymousIDkey = @"AnonymousID";
    NSString *anonymousID = nil;
    
    if ([preferences objectForKey:anonymousIDkey] == nil)
    {
        anonymousID = [self generateNewAnonymousID];
        [preferences setObject:anonymousID forKey:anonymousIDkey];
        [preferences synchronize];
    }   else {
        anonymousID = [preferences stringForKey:anonymousIDkey];
    }
    return anonymousID;
}

- (NSString *)generateNewAnonymousID
{
    NSString *uuid = [[NSUUID UUID] UUIDString];
    return uuid;
}

- (void)setUserInfoWithExternalID:(nullable NSString *)externalID
                 externalUserName:(nullable NSString *)externalUserName
                      phoneNumber:(nullable NSString *)phoneNumber
                            email:(nullable NSString *)email
                           origin:(nullable NSString *)origin
{
    NSString* hashedExternalID = [TikTokTypeUtility toSha256:externalID origin:origin];
    NSString* hashedExternalUserName = [TikTokTypeUtility toSha256:externalUserName origin:origin];
    NSString* hashedPhoneNumber = [TikTokTypeUtility toSha256:phoneNumber origin:origin];
    NSString* hashedEmail = [TikTokTypeUtility toSha256:email origin:origin];
    
    self.externalID = hashedExternalID;
    self.externalUserName = hashedExternalUserName;
    self.email = hashedEmail;
    self.phoneNumber = hashedPhoneNumber;
    self.isIdentified = YES;
}

- (NSDictionary *)getUserInfoDictionary
{
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    
    if (TTCheckValidString(self.externalID)) {
        [userInfo setObject:self.externalID forKey:@"external_id"];
    }
    if (TTCheckValidString(self.phoneNumber)) {
        [userInfo setObject:self.phoneNumber forKey:@"phone_number"];
    }
    if (TTCheckValidString(self.email)) {
        [userInfo setObject:self.email forKey:@"email"];
    }
    if (TTCheckValidString(self.externalUserName)) {
        [userInfo setObject:self.externalUserName forKey:@"external_username"];
    }
    
    return userInfo;
}

- (void)resetUserInfo
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *anonymousIDkey = @"AnonymousID";
    [preferences setObject:nil forKey:anonymousIDkey];
    [preferences synchronize];
    
    _email = nil;
    _externalID = nil;
    _phoneNumber = nil;
    _isIdentified = NO;
    _externalUserName = nil;
}


@end
