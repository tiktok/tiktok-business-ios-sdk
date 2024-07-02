//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokPaymentObserver.h"
#import "TikTokBusiness.h"
#import "TikTokLogger.h"
#import "TikTokFactory.h"
#import "TikTokTypeUtility.h"
#import <StoreKit/StoreKit.h>
#import <StoreKit/SKPaymentQueue.h>
#import <StoreKit/SKPaymentTransaction.h>

static NSMutableArray *g_pendingRequestors;

@interface TikTokPaymentProductRequestor : NSObject <SKProductsRequestDelegate>

@property (nonatomic, retain) SKPaymentTransaction *transaction;

- (instancetype) initWithTransaction: (SKPaymentTransaction *)transaction;
- (void)resolveProducts;

@end

@interface TikTokPaymentObserver () <SKPaymentTransactionObserver>

@property (nonatomic, weak) id<TikTokLogger> logger;

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
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self handleTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
            case SKPaymentTransactionStateFailed:
            case SKPaymentTransactionStateRestored:
            case SKPaymentTransactionStateDeferred:
                break;
        }
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
        NSString *data = [[NSUserDefaults standardUserDefaults] stringForKey:@"com.tiktok.appevents.PaymentObserver.originalTransaction"];
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
    NSString *transactionId = nil;
    
    switch (transaction.transactionState) {
        case SKPaymentTransactionStatePurchasing:
            break;
        case SKPaymentTransactionStatePurchased:
            transactionId = self.transaction.transactionIdentifier;
            break;
        case SKPaymentTransactionStateFailed:
            break;
        case SKPaymentTransactionStateRestored:
            break;
        default:
            break;
    }
    SKPayment *payment = transaction.payment;
    
    NSMutableDictionary *eventParameters = [[NSMutableDictionary alloc] initWithDictionary:@{
    }];

    if(product){

        [eventParameters addEntriesFromDictionary:@{
            @"currency": [product.priceLocale objectForKey:NSLocaleCurrencyCode] ? : @"",
            @"description": product.localizedTitle ? : @"",
            @"query":@"",
            @"type": @"auto"
        }];
        if(transactionId){
            [eventParameters setObject:transactionId forKey:@"order_id"];
        }

        NSMutableArray *contents = [[NSMutableArray alloc] init];

        for (NSUInteger idx = 0; idx < payment.quantity; idx++) {
            NSMutableDictionary *productDict = [[NSMutableDictionary alloc] initWithDictionary:@{
                @"price": [[NSNumber numberWithDouble:product.price.doubleValue] stringValue],
                @"quantity": @"1",
                @"content_type": product.productIdentifier
            }];
            if(transactionId){
                [productDict setObject:product.productIdentifier forKey:@"content_id"];
            }
            [contents addObject:productDict];
        }

        [eventParameters setObject:contents forKey:@"contents"];
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
    [eventParameters setObject:[[NSNumber numberWithDouble:valueToSum] stringValue] forKey:@"value"];
    [TikTokBusiness trackEvent:eventName withProperties:eventParameters];
}

- (NSData *)fetchDeviceReceipt
{
    NSURL *receiptURL = [NSBundle bundleForClass:[self class]].appStoreReceiptURL;
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    return receipt;
}

@end
