//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokIdentifyUtility.h"
#import "TikTokTypeUtility.h"
#import "TikTokAppEventUtility.h"

#define TT_last_session_id_key        @"last_session_id_key"
#define TT_last_session_time_key      @"last_session_time_key"

@interface TikTokIdentifyUtility ()
@property (nonatomic, strong, nullable) NSString *currentAppSessionID;
@property (nonatomic, strong, nullable) NSString *currentSessionStartTime;
@end

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
        [self _createSessionInfo];
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
    if ([self _isSHA256HashedString:externalID]) {
        self.externalID = externalID;
    } else {
        self.externalID = [TikTokTypeUtility toSha256:externalID origin:origin];
    }
    
    if ([self _isSHA256HashedString:externalUserName]) {
        self.externalUserName = externalUserName;
    } else {
        self.externalUserName = [TikTokTypeUtility toSha256:externalUserName origin:origin];
    }
    
    if ([self _isSHA256HashedString:phoneNumber]) {
        self.phoneNumber = phoneNumber;
    } else {
        self.phoneNumber = [TikTokTypeUtility toSha256:phoneNumber origin:origin];
    }
    
    if ([self _isSHA256HashedString:email]) {
        self.email = email;
    } else {
        self.email = [TikTokTypeUtility toSha256:email origin:origin];
    }
    
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

- (void)_createSessionInfo {
    self.currentAppSessionID = [[NSUUID UUID] UUIDString];
    self.currentSessionStartTime = [TikTokAppEventUtility getCurrentTimestampInISO8601];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *sessionIdFromDisk = [defaults objectForKey:TT_last_session_id_key];
    if (TTCheckValidString(sessionIdFromDisk)) {
        self.lastAppSessionID = sessionIdFromDisk;
    }
    NSString *sessionTimeFromDisk = [defaults objectForKey:TT_last_session_time_key];
    if (TTCheckValidString(sessionTimeFromDisk)) {
        self.lastSessionStartTime = sessionTimeFromDisk;
    }
    
    [defaults setObject:self.currentAppSessionID forKey:TT_last_session_id_key];
    [defaults setObject:self.currentSessionStartTime forKey:TT_last_session_time_key];
}

- (NSString *)appSessionID {
    return self.currentAppSessionID;
}

- (BOOL)_isSHA256HashedString:(NSString *)string {
    if (!TTCheckValidString(string)) {
        return NO;
    }
    
    NSString *pattern = @"^[0-9a-fA-F]{64}$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    return [predicate evaluateWithObject:string];
}


@end
