//
//  TikTokSKAdNetworkRuleEvent.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2024/5/23.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokSKAdNetworkRuleEvent.h"
#import "TikTokTypeUtility.h"

@implementation TikTokSKAdNetworkRuleEvent

- (instancetype)initWithDict:(NSDictionary *)dict {
    if (self = [super init]) {
        NSString *eventName = [dict objectForKey:@"event_name_report"];
        self.eventName = TTCheckValidString(eventName)?eventName:@"";
        
        NSNumber *minRev = [dict objectForKey:@"revenue_min"];
        self.minRevenue = TTCheckValidNumber(minRev)?minRev:@(0);
        
        NSNumber *maxRev = [dict objectForKey:@"revenue_max"];
        self.maxRevenue = TTCheckValidNumber(maxRev)?maxRev:@(0);
        
        self.isMatched = NO;
    }
    return self;
}

@end
