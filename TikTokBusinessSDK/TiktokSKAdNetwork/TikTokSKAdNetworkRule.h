//
//  TikTokSKAdNetworkRule.h
//  TikTokBusinessSDK
//
//  Created by Aditya Khandelwal on 5/5/21.
//  Copyright © 2021 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokSKAdNetworkRule : NSObject

@property (nonatomic) NSNumber *conversionValue;
@property (nonatomic, copy) NSString *eventName;
@property (nonatomic) NSNumber *minRevenue;
@property (nonatomic) NSNumber *maxRevenue;

- (nullable instancetype)initWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
