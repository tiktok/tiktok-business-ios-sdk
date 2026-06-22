//
//  TikTokSKAdNetworkWindow.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/11/10.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokSKAdNetworkRule.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokSKAdNetworkWindow : NSObject

@property (nonatomic, assign) NSInteger postbackIndex;

//@property (nonatomic) NSNumber *lock_window_time;
@property (nonatomic, copy) NSArray<TikTokSKAdNetworkRule *> *fineValueRules;
@property (nonatomic, copy) NSArray<TikTokSKAdNetworkRule *> *coarseValueRules;

- (instancetype)initWithDict:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
