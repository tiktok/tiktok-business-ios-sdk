//
//  TikTokSKAdNetworkRuleEvent.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/5/23.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokSKAdNetworkRuleEvent : NSObject

@property (nonatomic, copy) NSString *eventName;
@property (nonatomic) NSNumber *minRevenue;
@property (nonatomic) NSNumber *maxRevenue;
@property (nonatomic, assign) BOOL isMatched;

- (instancetype)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
