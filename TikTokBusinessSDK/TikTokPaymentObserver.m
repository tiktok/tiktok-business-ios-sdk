//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokPaymentObserver.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokAppEvent.h"
#import "TikTokLogger.h"
#import "TikTokFactory.h"
#import "TikTokTypeUtility.h"
#import <StoreKit/StoreKit.h>
#import <StoreKit/SKPaymentQueue.h>
#import <StoreKit/SKPaymentTransaction.h>
#import "TikTokBusinessSDKMacros.h"
#import "TikTokTypeUtility.h"
#import "TikTokEDPConfig.h"
#import "TikTokAppEventUtility.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

static NSMutableArray *g_pendingRequestors;

@interface TikTokPaymentProductRequestor : NSObject <SKProductsRequestDelegate>

@property (nonatomic, retain) SKPaymentTransaction *transaction;

- (instancetype) initWithTransaction: (SKPaymentTransaction *)transaction;
- (void)resolveProducts;

@end

@interface TikTokPaymentObserver () <SKPaymentTransactionObserver>

@property (nonatomic, strong) TikTokLogger *logger;

@end

@implementation TikTokPaymentObserver
{
    BOOL _observingTransactions;
}

+ (void)startObservingTransactions
{
    [[self singleton] startObservingTransactions];
}

+ (void)stopObservingTransactions
{
    [[self singleton] stopObservingTransactions];
}

#pragma mark - Internal Methods

+ (TikTokPaymentObserver *)singleton
{
    static dispatch_once_t pred;
    static TikTokPaymentObserver *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[TikTokPaymentObserver alloc] init];
    });
    
    return shared;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _observingTransactions = NO;
      self.logger = [TikTokFactory getLogger];
  }
  return self;
}

-(void)startObservingTransactions
{
    @synchronized (self) {
        if(!_observingTransactions) {
            [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
            _observingTransactions = YES;
            [self.logger info:@"Starting Transaction Tracking..."];
        }
    }
}

-(void)stopObservingTransactions
{
    @synchronized (self) {
        if(_observingTransactions) {
            [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
            _observingTransactions = NO;
            [self.logger info:@"Stopping Transaction Tracking..."];
        }
    }
}

- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
    for(SKPaymentTransaction *transaction in transactions) {
        [self handleTransaction:transaction];
    }
}

-(void)handleTransaction: (SKPaymentTransaction *)transaction
{
    TikTokPaymentProductRequestor *productRequest = [[TikTokPaymentProductRequestor alloc] initWithTransaction:transaction];
    [productRequest resolveProducts];
}

@end

@interface TikTokPaymentProductRequestor ()
@property (nonatomic, retain) SKProductsRequest *productRequest;
@end

@implementation TikTokPaymentProductRequestor
{
    NSMutableSet<NSString *> *_originalTransactionSet;
    NSSet<NSString *> *_eventsWithReceipt;
}

+ (void)initialize
{
    if([self class] == [TikTokPaymentProductRequestor class]) {
        g_pendingRequestors = [[NSMutableArray alloc] init];
    }
}

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction
{
    self = [super init];
    if (self) {
        _transaction = transaction;
        NSString *data = [[TikTokDefaults storage] stringForKey:TikTokDefaultsKeyPaymentObserverOriginalTransaction];
        _eventsWithReceipt = [NSSet setWithArray:@[@"Purchase"]];
        
        if (data) {
            _originalTransactionSet = [NSMutableSet setWithArray:[data componentsSeparatedByString:@","]];
        } else {
            _originalTransactionSet = [[NSMutableSet alloc] init];
        }
    }
    return self;
}

- (void)setProductRequest:(SKProductsRequest *)productRequest
{
    if(productRequest != _productRequest) {
        if(_productRequest){
            _productRequest.delegate = nil;
        }
        _productRequest = productRequest;
    }
}

- (void)resolveProducts
{
    NSString *productId = self.transaction.payment.productIdentifier;
    NSSet *productIdentifiers = [NSSet setWithObjects:productId, nil];
    self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productRequest.delegate = self;
    @synchronized (g_pendingRequestors) {
        [g_pendingRequestors addObject:self];
    }
    [self.productRequest start];
}

- (void)logTransactionEvent: (SKProduct *)product
{
    [self trackAutomaticPurchaseEvent:self.transaction ofProduct:product];
}

- (NSMutableDictionary<NSString *, id> *)getEventParametersOfProduct: (SKProduct *)product withTransaction: (SKPaymentTransaction *)transaction
{
    NSString *transactionId = TTSafeString(transaction.transactionIdentifier);
    
    SKPayment *payment = transaction.payment;
    
    NSMutableDictionary *eventParameters = [[NSMutableDictionary alloc] initWithDictionary:@{
    }];

    if(product && payment) {
        // order info
        NSDictionary *orderInfo = @{
            @"order_id": TTSafeString(transactionId),
            @"order_time": TTSafeString([TikTokAppEventUtility getCurrentTimestampAsString])
        };
        [TikTokTypeUtility dictionary:eventParameters setObject:orderInfo forKey:@"order"];

        [eventParameters addEntriesFromDictionary:@{
            @"currency": [product.priceLocale objectForKey:NSLocaleCurrencyCode] ? : @"",
            @"query":@"",
            @"code": @(transaction.transactionState),
            @"type": @"auto"
        }];

        NSMutableArray *contents = [[NSMutableArray alloc] init];
        NSString *contentType = product.subscriptionPeriod != nil ? @"SUB" : @"SKU";
        
        //basic product info
        NSMutableDictionary *productDict = [[NSMutableDictionary alloc] initWithDictionary:@{
            @"price": [[NSNumber numberWithDouble:product.price.doubleValue] stringValue],
            @"quantity": [NSString stringWithFormat:@"%ld",payment.quantity],
            @"content_type": TTSafeString(contentType),
            @"description": TTSafeString(product.localizedDescription),
            @"title": TTSafeString(product.localizedTitle),
        }];
        
        // subscription info
        if (product.subscriptionPeriod) {
            [TikTokTypeUtility dictionary:productDict setObject:@([self subscriptionPeriodInDays:product.subscriptionPeriod]) forKey:@"subscription_period"];
            [TikTokTypeUtility dictionary:productDict setObject:@(product.subscriptionPeriod.numberOfUnits) forKey:@"subscription_period_number"];
            [TikTokTypeUtility dictionary:productDict setObject:product.price.stringValue forKey:@"recurring_price"];
            
            if (@available(iOS 12.2,*)) {
                if (TTCheckValidArray(product.discounts)) {
                    SKProductDiscount *discount = product.discounts.firstObject;
                    if (discount && discount.paymentMode == SKProductDiscountPaymentModeFreeTrial) {
                        [TikTokTypeUtility dictionary:productDict setObject:@([self daysFromPeriodUnit:discount.subscriptionPeriod.unit]) forKey:@"free_trial_period"];
                    }
                }
            }
        }
        
        // discount info
        if (@available(iOS 12.2,*)) {
            if (TTCheckValidArray(product.discounts)) {
                NSMutableArray *discounts = [NSMutableArray array];
                for (SKProductDiscount *discount in product.discounts) {
                    if (discount) {
                        NSMutableDictionary *discountInfo = [NSMutableDictionary dictionary];
                        [TikTokTypeUtility dictionary:discountInfo setObject:TTSafeString(discount.identifier) forKey:@"offer_id"];
                        NSString *discountType = discount.type == SKProductDiscountTypeIntroductory ? @"Introductory" : @"Subscription";
                        [TikTokTypeUtility dictionary:discountInfo setObject:TTSafeString(discountType) forKey:@"type"];
                        [TikTokTypeUtility dictionary:discountInfo setObject:discount.price.stringValue forKey:@"price"];
                        [TikTokTypeUtility dictionary:discountInfo setObject:[self stringOfPaymentMode:discount.paymentMode] forKey:@"payment_mode"];
                        [TikTokTypeUtility dictionary:discountInfo setObject:@([self subscriptionPeriodInDays:discount.subscriptionPeriod]) forKey:@"discount_period"];
                        [TikTokTypeUtility dictionary:discountInfo setObject:@(discount.subscriptionPeriod.numberOfUnits) forKey:@"discount_period_number"];
                        [discounts addObject:discountInfo.copy];
                    }
                }
                [TikTokTypeUtility dictionary:productDict setObject:discounts.copy forKey:@"offers"];
            }
        }
        
        [TikTokTypeUtility dictionary:productDict setObject:product.productIdentifier forKey:@"content_id"];
        [contents addObject:productDict];
        
        [TikTokTypeUtility dictionary:eventParameters setObject:contents forKey:@"contents"];
    }
    return eventParameters;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *products = response.products;
    NSArray *invalidProductIdentifiers = response.invalidProductIdentifiers;
    if (products.count + invalidProductIdentifiers.count != 1) {
        [[TikTokFactory getLogger] info:@"TikTokPaymentObserver: Expect to resolve one product per request"];
    }
    SKProduct *product = nil;
    if (products.count) {
        product = [products objectAtIndex:0];
    }
    [self logTransactionEvent:product];
}

- (void)requestDidFinish:(SKRequest *)request
{
    [self cleanUp];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    [self logTransactionEvent:nil];
    [self cleanUp];
}

- (void)cleanUp
{
    @synchronized (g_pendingRequestors) {
        [g_pendingRequestors removeObject:self];
    }
}

- (void)trackAutomaticPurchaseEvent:(SKPaymentTransaction *)transaction ofProduct:(SKProduct *)product
{
    NSString *eventName = nil;
    switch (transaction.transactionState) {
        case SKPaymentTransactionStatePurchasing:
            eventName = @"Purchasing";
            break;
        case SKPaymentTransactionStatePurchased:
            eventName = @"Purchase";
            break;
        case SKPaymentTransactionStateFailed:
            eventName = @"PurchaseFailed";
            break;
        case SKPaymentTransactionStateRestored:
            eventName = @"PurchaseRestored";
            break;
        case SKPaymentTransactionStateDeferred:
            eventName = @"PurchaseDeferred";
            break;
    }
    
    double totalAmount = 0;
    if(product){
        totalAmount = transaction.payment.quantity * product.price.doubleValue;
    }
    
    if (TTCheckValidString(eventName)) {
        [self logImplicitTransactionEvent:eventName valueToSum:totalAmount parameters:[self getEventParametersOfProduct:product withTransaction:transaction]];
    }
}

- (void)logImplicitTransactionEvent: (NSString *)eventName valueToSum:(double)valueToSum parameters: (NSDictionary<NSString *, id>*)parameters
{
    NSMutableDictionary *eventParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [TikTokTypeUtility dictionary:eventParameters setObject:[[NSNumber numberWithDouble:valueToSum] stringValue] forKey:@"value"];
    [TikTokBusiness trackEvent:eventName withProperties:eventParameters];
    
    if ([TikTokEDPConfig sharedConfig].enable_sdk && [TikTokEDPConfig sharedConfig].enable_from_ttconfig && [TikTokEDPConfig sharedConfig].enable_pay_show_track) {
        [eventParameters setObject:@"enhanced_data_postback" forKey:@"monitor_type"];
        [TikTokBusiness trackEvent:@"pay_show" withProperties:eventParameters.copy];
    }
}

- (NSData *)fetchDeviceReceipt
{
    NSURL *receiptURL = [NSBundle bundleForClass:[self class]].appStoreReceiptURL;
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    return receipt;
}

- (NSUInteger)subscriptionPeriodInDays:(SKProductSubscriptionPeriod *)period {
    if (!period || period.numberOfUnits == 0) {
        return 0;
    }
    NSUInteger days = period.numberOfUnits * [self daysFromPeriodUnit:period.unit];
    return days;
}

- (NSUInteger)daysFromPeriodUnit:(SKProductPeriodUnit)unit {
    switch (unit) {
        case SKProductPeriodUnitDay:
            return 1;
        case SKProductPeriodUnitWeek:
            return 7;
        case SKProductPeriodUnitMonth:
            return 30;
        case SKProductPeriodUnitYear:
            return 365;
        default:
            return 0;
    }
}

- (NSString *)stringOfPaymentMode:(SKProductDiscountPaymentMode)paymentMode {
    switch (paymentMode) {
        case SKProductDiscountPaymentModePayAsYouGo:
            return @"pay_as_you_go";
        case SKProductDiscountPaymentModePayUpFront:
            return @"pay_up_front";
        case SKProductDiscountPaymentModeFreeTrial:
            return @"free_trial";
        default:
            return @"";
    }
}

@end
