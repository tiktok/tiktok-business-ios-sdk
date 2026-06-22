//
//  TikTokContentsEvent.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 2023/12/5.
//  Copyright © 2023 TikTok. All rights reserved.
//

#import "TikTokContentsEvent.h"
#import "TikTokTypeUtility.h"

NSString * const TTEventPropertyContentType = @"content_type";
NSString * const TTEventPropertyContentID   = @"content_id";
NSString * const TTEventPropertyDescription = @"description";
NSString * const TTEventPropertyCurrency    = @"currency";
NSString * const TTEventPropertyValue       = @"value";
NSString * const TTEventPropertyContents    = @"contents";

NSString * const TTContentsEventNameAddToCart     = @"AddToCart";
NSString * const TTContentsEventNameAddToWishlist = @"AddToWishlist";
NSString * const TTContentsEventNameCheckout      = @"Checkout";
NSString * const TTContentsEventNamePurchase      = @"Purchase";
NSString * const TTContentsEventNameViewContent   = @"ViewContent";



@implementation TikTokContentParams

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    [TikTokTypeUtility dictionary:res setObject:[NSString stringWithFormat:@"%@",self.price] forKey:@"price"];
    [TikTokTypeUtility dictionary:res setObject:@(self.quantity) forKey:@"quantity"];
    [TikTokTypeUtility dictionary:res setObject:self.contentId forKey:@"content_id"];
    [TikTokTypeUtility dictionary:res setObject:self.contentCategory forKey:@"content_category"];
    [TikTokTypeUtility dictionary:res setObject:self.contentName forKey:@"content_name"];
    [TikTokTypeUtility dictionary:res setObject:self.brand forKey:@"brand"];
    return res.copy;
}

@end

@implementation TikTokContentsEvent

- (void)setDescription:(NSString *)description {
    if (TTCheckValidString(description)) {
        [self addPropertyWithKey:TTEventPropertyDescription value:description];
    }
}

- (void)setCurrency:(TTCurrency)currency {
    if (TTCheckValidString(currency)) {
        [self addPropertyWithKey:TTEventPropertyCurrency value:currency];
    }
}

- (void)setValue:(NSString *)value {
    if (TTCheckValidString(value)) {
        [self addPropertyWithKey:TTEventPropertyValue value:value];
    }
}

- (void)setContentType:(NSString *)contentType {
    if (TTCheckValidString(contentType)) {
        [self addPropertyWithKey:TTEventPropertyContentType value:contentType];
    }
}

- (void)setContentId:(NSString *)contentId {
    if (TTCheckValidString(contentId)) {
        [self addPropertyWithKey:TTEventPropertyContentID value:contentId];
    }
}

- (void)setContents:(NSArray<TikTokContentParams *> *)contents {
    if (TTCheckValidArray(contents)) {
        NSMutableArray * array = [NSMutableArray array];
        for (TikTokContentParams * content in contents) {
            [array addObject:[content dictionaryValue]];
        }
        [self addPropertyWithKey:TTEventPropertyContents value:array.copy];
    }
}

@end

@implementation TikTokAddToCartEvent

- (instancetype)init
{
    return [self initWithEventName:TTContentsEventNameAddToCart];
}

- (instancetype)initWithEventId:(nonnull NSString *)eventId {
    return [self initWithEventName:TTContentsEventNameAddToCart eventId:eventId];
}

@end

@implementation TikTokAddToWishlistEvent

- (instancetype)init
{
    return [self initWithEventName:TTContentsEventNameAddToWishlist];
}

- (instancetype)initWithEventId:(nonnull NSString *)eventId {
    return [self initWithEventName:TTContentsEventNameAddToWishlist eventId:eventId];
}

@end


@implementation TikTokCheckoutEvent

- (instancetype)init
{
    return [self initWithEventName:TTContentsEventNameCheckout];
}

- (instancetype)initWithEventId:(nonnull NSString *)eventId {
    return [self initWithEventName:TTContentsEventNameCheckout eventId:eventId];
}

@end


@implementation TikTokPurchaseEvent

- (instancetype)init
{
    return [self initWithEventName:TTContentsEventNamePurchase];
}

- (instancetype)initWithEventId:(nonnull NSString *)eventId {
    return [self initWithEventName:TTContentsEventNamePurchase eventId:eventId];
}

@end


@implementation TikTokViewContentEvent

- (instancetype)init
{
    return [self initWithEventName:TTContentsEventNameViewContent];
}

- (instancetype)initWithEventId:(nonnull NSString *)eventId {
    return [self initWithEventName:TTContentsEventNameViewContent eventId:eventId];
}

@end



@implementation TikTokAdRevenueEvent

- (instancetype)init
{
    return [self initWithEventName:TTEventNameImpressionLevelAdRevenue];
}

- (instancetype)initWithAdRevenue:(NSDictionary *)adRevenue eventId:(nonnull NSString *)eventId {
    TikTokAdRevenueEvent *adRevenueEvent = [self initWithEventName:TTEventNameImpressionLevelAdRevenue eventId:eventId];
    [adRevenueEvent addPropertyWithKey:@"ad_revenue" value:adRevenue];
    return adRevenueEvent;
}

@end
