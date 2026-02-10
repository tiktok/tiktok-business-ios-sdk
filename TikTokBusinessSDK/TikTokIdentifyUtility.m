//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokIdentifyUtility.h"
#import "TikTokTypeUtility.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

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
    NSUserDefaults *preferences = [TikTokDefaults storage];
    NSString *anonymousID = nil;
    
    if ([preferences objectForKey:TikTokDefaultsKeyAnonymousID] == nil)
    {
        anonymousID = [self generateNewAnonymousID];
        [preferences setObject:anonymousID forKey:TikTokDefaultsKeyAnonymousID];
        [preferences synchronize];
    }   else {
        anonymousID = [preferences stringForKey:TikTokDefaultsKeyAnonymousID];
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
    [TikTokTypeUtility dictionary:userInfo setObject:self.externalID forKey:@"external_id"];
    [TikTokTypeUtility dictionary:userInfo setObject:self.phoneNumber forKey:@"phone_number"];
    [TikTokTypeUtility dictionary:userInfo setObject:self.email forKey:@"email"];
    [TikTokTypeUtility dictionary:userInfo setObject:self.externalUserName forKey:@"external_username"];
    
    return userInfo.copy;
}

- (void)resetUserInfo
{
    NSUserDefaults *preferences = [TikTokDefaults storage];
    [preferences setObject:nil forKey:TikTokDefaultsKeyAnonymousID];
    [preferences synchronize];
    
    _email = nil;
    _externalID = nil;
    _phoneNumber = nil;
    _isIdentified = NO;
    _externalUserName = nil;
}

- (NSString *)app_session_id {
    if (!_app_session_id) {
        _app_session_id = [[NSUUID UUID] UUIDString];
    }
    return _app_session_id;
}


@end
