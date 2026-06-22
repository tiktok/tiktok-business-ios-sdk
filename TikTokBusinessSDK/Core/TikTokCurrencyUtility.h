//
//  TikTokCurrencyUtility.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/5/21.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TikTokExchangeErrReason) {
    TikTokCurrencyExchangeErrReasonExchangeInfoEmpty      = 1 << 0,
    TikTokCurrencyExchangeErrReasonEventCurrencyInvalid   = 1 << 1,
    TikTokCurrencyExchangeErrReasonSKANCurrencyInvalid    = 1 << 2,
};

@interface TikTokCurrencyUtility : NSObject

@property (nonatomic, strong) NSDictionary *currencyExchangeInfo;

+ (instancetype)sharedInstance;
- (void)configWithDict:(NSDictionary *)dict;
- (NSNumber *)exchangeAmount:(NSNumber *)amount fromCurrency:(NSString *)fromCurrency toCurrency:(NSString *)toCurrency shouldReport:(BOOL)shouldReport;

@end

NS_ASSUME_NONNULL_END
