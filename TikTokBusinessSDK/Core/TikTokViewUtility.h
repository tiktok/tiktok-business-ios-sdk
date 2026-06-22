//
//  TikTokViewUtility.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/2/29.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokViewUtility : NSObject

+ (NSDictionary *)digView:(UIView *)view atDepth:(NSInteger)depth maxDepth:(NSInteger *)maxDepth;

+ (UIView *)bottommostSuperviewOfView:(UIView *)view;

+ (NSInteger)maxDepthOfSubviews:(UIView *)view;

+ (UIViewController *)getParentVCof: (UIView *)view;

@end

NS_ASSUME_NONNULL_END
