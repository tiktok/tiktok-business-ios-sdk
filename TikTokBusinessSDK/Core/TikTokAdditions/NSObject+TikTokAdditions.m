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

@implementation NSObject (TikTokAdditions)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (!appName) {
            appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        }
        Class class = NSClassFromString([NSString stringWithFormat:@"%@.AppDelegate",appName]);
        
        Method originalMethod = class_getInstanceMethod(class, @selector(application:openURL:options:));
        Method swizzledMethod = class_getInstanceMethod([self class], @selector(hook_application:openURL:options:));
        if (originalMethod && swizzledMethod) {
            if (class_addMethod(class, @selector(application:openURL:options:), method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
                class_replaceMethod(class, @selector(hook_application:openURL:options:), method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
    });
}

- (BOOL)hook_application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:TTSafeString(url.absoluteString) forKey:@"source_url"];
    [defaults setObject:TTSafeString([options objectForKey:UIApplicationOpenURLOptionsSourceApplicationKey]) forKey:@"refer"];
    [defaults synchronize];
    return [self hook_application:application openURL:url options:options];
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
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:TTSafeString(launchURL.absoluteString) forKey:@"source_url"];
    [defaults setObject:TTSafeString(refer) forKey:@"refer"];
    [defaults synchronize];
}

@end
