//
//  UIViewController+TikTokAdditions.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/26.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSInteger pageIndex = 0;

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (TikTokAdditions)

+ (void)TT_StartUIViewControllerEDPMonitoring;

@end

NS_ASSUME_NONNULL_END
