//
//  UIViewController+TikTokAdditions.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/26.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import "UIViewController+TikTokAdditions.h"
#import "TikTokbusiness.h"
#import "TikTokbusiness+private.h"
#import <objc/runtime.h>
#import "TikTokViewUtility.h"
#import "TikTokAppEvent.h"
#import "TikTokEDPConfig.h"


@implementation UIViewController (TikTokAdditions)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(hook_viewDidAppear:);
        
        TTSwizzleSelector(class, originalSelector, swizzledSelector);
    });
}

- (void)hook_viewDidAppear:(BOOL)animated {
    [self hook_viewDidAppear:animated];
    if (!([TikTokEDPConfig sharedConfig].enable_sdk && [TikTokEDPConfig sharedConfig].enable_from_ttconfig && [TikTokEDPConfig sharedConfig].enable_page_show_track)) {
        return;
    }
    // Report when navigating between pages.
    NSInteger pageDepth = 0;
    NSDictionary *viewTree = [TikTokViewUtility digView:self.view atDepth:0 maxDepth:&pageDepth];
    NSDictionary *pageShowProperties = @{
        @"current_page_name": NSStringFromClass([self class]),
        @"index": @(pageIndex),
        @"from_background": @(NO),
        @"page_components": viewTree,
        @"page_deep_count": @([TikTokViewUtility maxDepthOfSubviews:self.view]),
        @"monitor_type": @"enhanced_data_postback"
    };
    [TikTokBusiness trackEvent:@"page_show" withProperties:pageShowProperties];
    pageIndex++;
}

static inline void TTSwizzleSelector(Class class, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@end
