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

@property (nonatomic, assign) NSInteger fineConversionValue;
@property (nonatomic) NSString *coarseConversionValue;
@property (nonatomic, copy) NSArray *eventFunnel;
//@property (nonatomic, assign) BOOL lockWindow;

- (instancetype)initWithDict:(NSDictionary *)dict;

- (BOOL)isMatched;

@end

NS_ASSUME_NONNULL_END
