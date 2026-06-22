//
//  TikTokSKAdNetworkRule.m
//  TikTokBusinessSDK
//
//  Created by Aditya Khandelwal on 5/5/21.
//  Copyright © 2021 TikTok. All rights reserved.
//

#import "TikTokSKAdNetworkRule.h"
#import "TikTokTypeUtility.h"
#import "TikTokSKAdNetworkRuleEvent.h"

@implementation TikTokSKAdNetworkRule

- (instancetype)initWithDict:(NSDictionary *)dict
{
    if((self = [super init])){
        NSString *conversionValue = [dict objectForKey:@"conversion_value"];
        if (TTCheckValidString(conversionValue)) {
            self.fineConversionValue = [conversionValue integerValue] ?: 0;
            self.coarseConversionValue = conversionValue;
        }
        NSMutableArray *eventFunnel = [NSMutableArray array];
        NSArray *funnel = [dict objectForKey:@"event_funnel"];
        if (TTCheckValidArray(funnel)) {
            for (NSDictionary *ruleEventDict in funnel) {
                TikTokSKAdNetworkRuleEvent *event = [[TikTokSKAdNetworkRuleEvent alloc] initWithDict:ruleEventDict];
                [eventFunnel addObject:event];
            }
        }
        self.eventFunnel = eventFunnel;
    }
    return self;
}

- (BOOL)isMatched {
    BOOL isMatched = YES;
    for (TikTokSKAdNetworkRuleEvent *event in self.eventFunnel) {
        isMatched = isMatched && event.isMatched;
    }
    return isMatched;
}

@end
