//
//  TikTokContentsEvent.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/5.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TikTokBaseEvent.h"
#import "TikTokConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface TikTokContentParams : NSObject

@property (nonatomic, strong) NSNumber *price;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, strong, nullable) NSString *contentId;
@property (nonatomic, strong, nullable) NSString *contentCategory;
@property (nonatomic, strong, nullable) NSString *contentName;
@property (nonatomic, strong, nullable) NSString *brand;

- (NSDictionary *)dictionaryValue;

@end

@interface TikTokContentsEvent : TikTokBaseEvent

- (void)setDescription:(NSString *)description;
- (void)setCurrency:(TTCurrency)currency;
- (void)setValue:(NSString *)value;
- (void)setContentType:(NSString *)contentType;
- (void)setContentId:(NSString *)contentId;
- (void)setContents:(NSArray<TikTokContentParams *> *)contents;

@end

@interface TikTokAddToCartEvent : TikTokContentsEvent

- (instancetype)initWithEventId:(NSString *)eventId;

@end

@interface TikTokAddToWishlistEvent : TikTokContentsEvent

- (instancetype)initWithEventId:(NSString *)eventId;

@end

@interface TikTokCheckoutEvent : TikTokContentsEvent

- (instancetype)initWithEventId:(NSString *)eventId;

@end

@interface TikTokPurchaseEvent : TikTokContentsEvent

- (instancetype)initWithEventId:(NSString *)eventId;

@end

@interface TikTokViewContentEvent : TikTokContentsEvent

- (instancetype)initWithEventId:(NSString *)eventId;

@end

NS_ASSUME_NONNULL_END
