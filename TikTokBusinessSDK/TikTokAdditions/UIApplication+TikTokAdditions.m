//
//  UIApplication+TikTokAdditions.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/3/18.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "UIApplication+TikTokAdditions.h"
#import <objc/runtime.h>
#import "TikTokViewUtility.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokBusinessSDKMacros.h"
#import "TikTokAppEventUtility.h"
#import "TikTokAppEvent.h"
#import "TikTokEDPConfig.h"
#import "TikTokTypeUtility.h"

@implementation UIApplication (EDP)

static UIView *tempView;
static long long touchStart;
static long long previousTouch;

+ (void)TT_StartUIApplicationEDPMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector2 = @selector(sendEvent:);
        SEL swizzledSelector2 = @selector(hook_sendEvent:);
        
        TTSwizzleSelector(class, originalSelector2, swizzledSelector2);
    });
}

- (void)hook_sendEvent:(UIEvent *)event {
    [self hook_sendEvent:event];
    if (!([TikTokEDPConfig sharedConfig].enable_sdk && [TikTokEDPConfig sharedConfig].enable_from_ttconfig && [TikTokEDPConfig sharedConfig].enable_click_track)) {
        return;
    }
    
    UITouch *touch = [event.allTouches anyObject];
    // GestureRecognizer has higher priority than UIResponder. When a gesture happens, system will trigger touchesBegan & touchesCancelled. The view in touchesCancelled will be nil, so we need to retain the view in touchesBegan.
    UIView *v = touch.view ? touch.view : tempView;
    if (touch.phase == UITouchPhaseBegan) {
        touchStart = [TikTokAppEventUtility getCurrentTimestamp];
        
        tempView = v;
    } else if (touch.phase == UITouchPhaseEnded) {
        long long currentTime =  [TikTokAppEventUtility getCurrentTimestamp];
        // Should report after the time interval in config
        BOOL afterInterval = !previousTouch || (currentTime - previousTouch) >= [TikTokEDPConfig sharedConfig].time_diff_frequency_control * 1000;
        
        // Should report under possibility in config
        BOOL shouldReport = (arc4random() % 100) < [TikTokEDPConfig sharedConfig].report_frequency_control * 100;
        
        // Will be filtered if buttonText contains any blocked text
        NSString *labelText = @"";
        if ([v isKindOfClass:[UIButton class]]) {
            // click on UIButton
            UIButton *button = (UIButton *)v;
            labelText = button.titleLabel.text;
        } else if ([v isKindOfClass:[UILabel class]]) {
            // click on gestureRecognizer attached to UILabel
            UILabel *label = (UILabel *)v;
            labelText = label.text;
        }
        NSString *className = NSStringFromClass([v class]);
        BOOL textFiltered = NO;
        if (TTCheckValidString(className)) {
            for (NSString *blockString in [TikTokEDPConfig sharedConfig].button_black_list) {
                if (TTCheckValidString(blockString) && [className isEqualToString:blockString]) {
                    textFiltered = YES;
                    break;
                }
            }
        }
        
        if (afterInterval && shouldReport && !textFiltered) {
            CGPoint point = [touch locationInView:nil];
            previousTouch = currentTime;
            UIViewController *parentVC = [TikTokViewUtility getParentVCof:v];
            UIView *bottomMostSuperView = [TikTokViewUtility bottommostSuperviewOfView:v];
            NSInteger pageDepth = 0;
            NSDictionary *viewTree = [TikTokViewUtility digView:parentVC.view atDepth:0 maxDepth:&pageDepth];
            long long duration = [TikTokAppEventUtility getCurrentTimestamp] - touchStart;
            NSDictionary *clickProperties = @{
                @"click_position_x": @(point.x),
                @"click_position_y": @(point.y),
                @"click_size_w": @(v.frame.size.width),
                @"click_size_h": @(v.frame.size.height),
                @"click_button_text": TTSafeString(labelText),
                @"current_page_name": TTSafeString(NSStringFromClass([parentVC class])),
                @"page_components": viewTree,
                @"page_deep_count": @([TikTokViewUtility maxDepthOfSubviews:bottomMostSuperView]),
                @"click_duration": @(duration),
                @"monitor_type": @"enhanced_data_postback",
                @"class_name": TTSafeString(NSStringFromClass([v class]))
            };
            [TikTokBusiness trackEvent:@"click" withProperties:clickProperties];
        }
        
        tempView = nil;
    }
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

