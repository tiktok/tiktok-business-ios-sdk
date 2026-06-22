//
//  TikTokSKANEventPersistence.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2/8/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokConstants.h"
#import "TikTokBaseEventPersistence.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokSKANEventPersistence : TikTokBaseEventPersistence

- (BOOL)persistSKANEventWithName:(NSString *)eventName value:(NSNumber *)value currency:(nullable TTCurrency)currency;

@end

NS_ASSUME_NONNULL_END
