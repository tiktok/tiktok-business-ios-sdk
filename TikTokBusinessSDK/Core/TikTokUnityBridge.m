//
//  TikTokUnityBridge.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 10/24/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokUnityBridge.h"
#import <objc/runtime.h>

@implementation TikTokUnityBridge

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
+ (void)sendConfigCallback:(NSDictionary *)configDict {
    Class unityFrameworkClass = NSClassFromString(@"UnityFramework");
    SEL getInstanceSEL = NSSelectorFromString(@"getInstance");
    if (unityFrameworkClass && getInstanceSEL) {
        if ([unityFrameworkClass respondsToSelector:getInstanceSEL]) {
            id unityFrameworkInstance = [unityFrameworkClass performSelector:getInstanceSEL];
            SEL selector = NSSelectorFromString(@"sendMessageToGOWithName:functionName:message:");
            if (unityFrameworkInstance && [unityFrameworkInstance respondsToSelector:selector]) {
                NSMethodSignature *methodSignature = [unityFrameworkInstance methodSignatureForSelector:selector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
                [invocation setSelector:selector];
                [invocation setTarget:unityFrameworkInstance];
                char *name = "TikTokInnerManager";
                char *functionName = "UpdateConfigFromNative";
                [invocation setArgument:&name atIndex:2];
                [invocation setArgument:&functionName atIndex:3];
                NSError *error;
                NSData *configData = [NSJSONSerialization dataWithJSONObject:configDict options:NSJSONWritingPrettyPrinted error:&error];
                NSString *configString = [[NSString alloc] initWithData:configData encoding:NSUTF8StringEncoding];
                if (error) {
                    configString = @"";
                }
                char *copiedConfigString = strdup([configString UTF8String]);
                [invocation setArgument:&copiedConfigString atIndex:4];
                [invocation invoke];
                free(copiedConfigString);
            }
        }
    }
}
#pragma clang diagnostic pop

@end
