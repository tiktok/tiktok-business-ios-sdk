//
//  TikTokUnityBridge.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 10/24/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokUnityBridge : NSObject

+ (void)sendConfigCallback:(NSDictionary *)configDict;

@end

NS_ASSUME_NONNULL_END
