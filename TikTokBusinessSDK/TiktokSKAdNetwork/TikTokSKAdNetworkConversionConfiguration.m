//
//  TikTokSKAdNetworkConversionConfiguration.m
//  TikTokBusinessSDK
//
//  Created by Aditya Khandelwal on 5/5/21.
//  Copyright © 2021 TikTok. All rights reserved.
//

#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokTypeUtility.h"

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


- (nullable instancetype)initWithDict:(NSDictionary *)dict
{
    if ((self = [super init])) {
                
        @try {
            _conversionValueConfig = [dict objectForKey:@"skan_event_config"];
            _conversionValueRules = [[NSMutableArray alloc] init];
            for(id conversionRule in _conversionValueConfig){
                TikTokSKAdNetworkRule *convRule = [[TikTokSKAdNetworkRule alloc] initWithDict:conversionRule];
                [_conversionValueRules addObject:convRule];
            }
            // Reversing the array
            _conversionValueRules = [[[_conversionValueRules reverseObjectEnumerator] allObjects] mutableCopy];
        } @catch(NSException *exception) {
            return nil;
        }
    
    }
    
    return self;
}

- (void)logAllRules
{
    for(TikTokSKAdNetworkRule *rule in _conversionValueRules){
        NSLog(@"Rule: %@ -> %@, %@, %@", rule.eventName, rule.conversionValue, rule.maxRevenue, rule.minRevenue);
    }
}

@end
