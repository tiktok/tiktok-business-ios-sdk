//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "TikTokSKAdNetworkWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokSKAdNetworkSupport : NSObject

@property (nonatomic, assign) NSNumber *currentConversionValue;

/* The maximum time for app install attribution is set to 3 days by default,
 * but this value can be changed using setSKAdNetworkCalloutMaxTimeSinceInstall()
 * through TikTokBusiness
*/
+ (TikTokSKAdNetworkSupport *)sharedInstance;
- (void)registerAppForAdNetworkAttribution;
- (void)updateConversionValue:(NSInteger)conversionValue;
- (void)matchEventToSKANConfig:(NSString *)eventName withValue:(nullable NSString *)value currency:(nullable NSString *)currency;
- (void)matchPersistedSKANEventsInWindow:(TikTokSKAdNetworkWindow *)window;
- (NSInteger)getConversionWindowForTimestamp:(long long)timeStamp;
//- (BOOL)canClearCachedEvents;

@end

NS_ASSUME_NONNULL_END
