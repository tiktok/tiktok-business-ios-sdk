//
//  TikTokSKAdNetworkRule.m
//  TikTokBusinessSDK
//
//  Created by Aditya Khandelwal on 5/5/21.
//  Copyright © 2021 TikTok. All rights reserved.
//

#import "TikTokSKAdNetworkRule.h"
#import "TikTokTypeUtility.h"

@implementation TikTokSKAdNetworkRule

- (nullable instancetype)initWithDict:(NSDictionary *)dict
{
    if((self = [super init])){
        
        dict = [TikTokTypeUtility dictionaryValue:dict];
        if(!dict){
            return nil;
        }
        NSNumber *conversionValue = [dict objectForKey:@"conversion_value"];
        _conversionValue = conversionValue;
        id eventDictionary = [dict objectForKey:@"event_funnel"][0];
        NSString *eventName = [eventDictionary objectForKey:@"event_name_report"];
        _eventName = eventName;
        _minRevenue = [dict objectForKey:@"revenue_min"];
        _maxRevenue = [dict objectForKey:@"revenue_max"];
    }
    return self;
}

@end
