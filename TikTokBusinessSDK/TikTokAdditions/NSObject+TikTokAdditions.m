//
//  NSObject+TikTokAdditions.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/5/30.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "NSObject+TikTokAdditions.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokAppEventUtility.h"
#import "TikTokAppEvent.h"
#import "TikTokEDPConfig.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

@implementation NSObject (TikTokAdditions)

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDidFinishLaunchingNotification:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
}

+ (void)handleDidFinishLaunchingNotification:(NSNotification *)notification {
    NSDictionary *launchOptions = notification.userInfo;
    NSURL *launchURL = [launchOptions valueForKey:UIApplicationLaunchOptionsURLKey];
    NSString *sourceApp = [launchOptions valueForKey:UIApplicationLaunchOptionsSourceApplicationKey];
    UIApplicationShortcutItem *item = [launchOptions valueForKey:UIApplicationLaunchOptionsShortcutItemKey];
    NSDictionary *notiDict = [launchOptions valueForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
    NSString *refer = nil;
    if (sourceApp) {
        return;
    } else if (item) {
        refer = item.localizedTitle;
    } else if (notiDict) {
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:notiDict options:NSJSONWritingPrettyPrinted error:&error];
        refer = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    } else if (!item && !notiDict) {
        refer = @"";
    }
    
    NSUserDefaults *defaults = [TikTokDefaults storage];
    [defaults setObject:TTSafeString(launchURL.absoluteString) forKey:TikTokDefaultsKeySourceURL];
    [defaults setObject:TTSafeString(refer) forKey:TikTokDefaultsKeyRefer];
    [defaults synchronize];
}

@end
