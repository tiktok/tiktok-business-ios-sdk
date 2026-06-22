//
//  TikTokSKAdNetworkWindow.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/11/10.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import "TikTokSKAdNetworkWindow.h"
#import "TikTokTypeUtility.h"

@implementation TikTokSKAdNetworkWindow

- (instancetype)initWithDict:(NSDictionary *)dict
{
    if((self = [super init])){
        NSNumber *index = [dict objectForKey:@"postback_index"];
        if (TTCheckValidNumber(index)) {
            self.postbackIndex = [index integerValue];
        }
        
        NSMutableArray *fineRules = [NSMutableArray array];
        NSArray *fine = [dict objectForKey:@"fine"];
        if (TTCheckValidArray(fine)) {
            for(NSDictionary *rule in fine){
                if (TTCheckValidDictionary(rule)) {
                    TikTokSKAdNetworkRule *fineRule = [[TikTokSKAdNetworkRule alloc] initWithDict:rule];
                    [fineRules addObject:fineRule];
                }
            }
            [fineRules sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                TikTokSKAdNetworkRule *rule1 = (TikTokSKAdNetworkRule *)obj1;
                TikTokSKAdNetworkRule *rule2 = (TikTokSKAdNetworkRule *)obj2;
                if (rule1.fineConversionValue > rule2.fineConversionValue) {
                    return NSOrderedAscending;
                } else if (rule1.fineConversionValue < rule2.fineConversionValue) {
                    return NSOrderedDescending;
                } else {
                    return NSOrderedSame;
                }
            }];
        }
        self.fineValueRules = fineRules.copy;
        
        NSMutableArray *coarseRules = [NSMutableArray array];
        NSArray *coarse = [dict objectForKey:@"coarse"];
        if (TTCheckValidArray(coarse)) {
            for(NSDictionary *rule in coarse){
                if (TTCheckValidDictionary(rule)) {
                    TikTokSKAdNetworkRule *coarseRule = [[TikTokSKAdNetworkRule alloc] initWithDict:rule];
                    [coarseRules addObject:coarseRule];
                }
            }
            [coarseRules sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                TikTokSKAdNetworkRule *rule1 = (TikTokSKAdNetworkRule *)obj1;
                TikTokSKAdNetworkRule *rule2 = (TikTokSKAdNetworkRule *)obj2;
                
                if ([rule1.coarseConversionValue isEqualToString:@"high"]) {
                    return NSOrderedAscending;
                } else if ([rule2.coarseConversionValue isEqualToString:@"high"]) {
                    return NSOrderedDescending;
                } else if ([rule1.coarseConversionValue isEqualToString:@"medium"]) {
                    return NSOrderedAscending;
                } else if ([rule2.coarseConversionValue isEqualToString:@"medium"]) {
                    return NSOrderedDescending;
                } else {
                    return NSOrderedSame;
                }
            }];
        }
        self.coarseValueRules = coarseRules.copy;
    }
    return self;
}

@end
