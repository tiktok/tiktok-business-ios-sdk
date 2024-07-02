//
//  TikTokSKAdNetworkConversionConfiguration.h
//  TikTokBusinessSDK
//
//  Created by Aditya Khandelwal on 5/5/21.
//  Copyright © 2021 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokSKAdNetworkRule.h"
#import "TikTokSKAdNetworkWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokSKAdNetworkConversionConfiguration : NSObject

@property (nonatomic, readonly, copy) NSArray<TikTokSKAdNetworkWindow *> *conversionValueWindows;
@property (nonatomic, readonly, copy) NSDictionary *configDict;
@property (nonatomic, strong) NSString *currency;

+ (TikTokSKAdNetworkConversionConfiguration *)sharedInstance;
- (void)configWithDict:(NSDictionary *)dict;
- (void)logAllRules;

@end

NS_ASSUME_NONNULL_END
