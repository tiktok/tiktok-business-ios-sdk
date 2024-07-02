//
//  TikTokCurrencyUtility.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/5/21.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokCurrencyUtility.h"
#import "TikTokTypeUtility.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"

@implementation TikTokCurrencyUtility

+ (instancetype)sharedInstance {
    static TikTokCurrencyUtility *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[TikTokCurrencyUtility alloc] init];
    });
    return singleton;
}

- (void)configWithDict:(NSDictionary *)dict {
    if (TTCheckValidDictionary(dict)) {
        self.currencyExchangeInfo = dict;
    }
}

- (NSNumber *)exchangeAmount:(NSNumber *)amount fromCurrency:(NSString *)fromCurrency toCurrency:(NSString *)toCurrency shouldReport:(BOOL)shouldReport {
    if (!TTCheckValidString(fromCurrency) || !TTCheckValidString(toCurrency)) {
        return amount;
    }
    NSInteger errReason = 0;
    if (!TTCheckValidDictionary(self.currencyExchangeInfo)) {
        errReason |= TikTokCurrencyExchangeErrReasonExchangeInfoEmpty;
    }
    NSNumber *rateFrom = [self.currencyExchangeInfo objectForKey:fromCurrency];
    NSNumber *rateTo = [self.currencyExchangeInfo objectForKey:toCurrency];
    if (!TTCheckValidNumber(rateFrom) || [rateFrom doubleValue] == 0) {
        errReason |= TikTokCurrencyExchangeErrReasonEventCurrencyInvalid;
    }
    if (!TTCheckValidNumber(rateTo) || [rateTo doubleValue] == 0) {
        errReason |= TikTokCurrencyExchangeErrReasonSKANCurrencyInvalid;
    }
    if (errReason && shouldReport) {
        NSInteger x = arc4random() % 100;
        BOOL willReport = x < [[TikTokBusiness getInstance] exchangeErrReportRate] * 100;
        if (willReport) {
            NSMutableDictionary *exchangeErrMeta = @{
                @"event_currency": fromCurrency,
                @"skan_currency": toCurrency,
                @"amount": TTCheckValidNumber(amount)?amount:@(0)
            }.mutableCopy;
            [self reportExchangeErrorWithMeta:exchangeErrMeta reason:errReason];
        }
        return amount;
    }
    double result = [amount doubleValue] / [rateFrom doubleValue] * [rateTo doubleValue];
    return [NSNumber numberWithDouble:result];
}

- (void)reportExchangeErrorWithMeta:(NSDictionary *)meta reason:(NSInteger)reason {
    NSDictionary *monitorExchangeErrProperties = @{
        @"monitor_type": @"metric",
        @"monitor_name": @"currency_exchange_err",
        @"meta": meta,
        @"extra": @{
            @"reason": [NSString stringWithFormat:@"%ld",(long)reason]
        }
    };
    TikTokAppEvent *exchangeErrEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorExchangeErrProperties withType:@"monitor"];
    [[TikTokBusiness getQueue] addEvent:exchangeErrEvent];
}

@end
