//
//  TikTokSKAdNetworkConversionConfiguration.m
//  TikTokBusinessSDK
//
//  Created by Aditya Khandelwal on 5/5/21.
//  Copyright © 2021 TikTok. All rights reserved.
//

#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokTypeUtility.h"
#import "TikTokSKAdNetworkRuleEvent.h"

@implementation TikTokSKAdNetworkConversionConfiguration

+ (TikTokSKAdNetworkConversionConfiguration *)sharedInstance
{
    static TikTokSKAdNetworkConversionConfiguration *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[TikTokSKAdNetworkConversionConfiguration alloc] init];
    });
    return singleton;
}


- (void)configWithDict:(NSDictionary *)dict
{
    @try {
        if (TTCheckValidDictionary(dict)) {
            _configDict = dict;
            NSString *currency = [dict objectForKey:@"currency"];
            _currency = TTCheckValidString(currency)?currency:@"USD";
            NSArray *postbacks = [dict objectForKey:@"postbacks"];
            if (TTCheckValidArray(postbacks)) {
                NSMutableArray *windows = [NSMutableArray array];
                for (NSDictionary *windowDict in postbacks) {
                    if (TTCheckValidDictionary(windowDict)) {
                        TikTokSKAdNetworkWindow *window = [[TikTokSKAdNetworkWindow alloc] initWithDict:windowDict];
                        [windows addObject:window];
                    }
                }
                _conversionValueWindows = windows.copy;
            }
        }
    } @catch(NSException *exception) {
        NSLog(@"failed to config SKAN rules");
    }
    [self logAllRules];
}

- (void)logAllRules
{
    for(TikTokSKAdNetworkWindow *window in self.conversionValueWindows) {
        for (TikTokSKAdNetworkRule *rule in window.fineValueRules) {
            NSLog(@"Rule: fineValue -> %ld", rule.fineConversionValue);
            for(TikTokSKAdNetworkRuleEvent *event in rule.eventFunnel) {
                NSLog(@"EventName: %@, max:%@, min:%@", event.eventName, event.maxRevenue, event.minRevenue);
            }
        }
        for (TikTokSKAdNetworkRule *rule in window.coarseValueRules) {
            NSLog(@"Rule: coarseValue -> %@", rule.coarseConversionValue);
            for(TikTokSKAdNetworkRuleEvent *event in rule.eventFunnel) {
                NSLog(@"EventName: %@, max:%@, min:%@", event.eventName, event.maxRevenue, event.minRevenue);
            }
        }
    }
}

@end
