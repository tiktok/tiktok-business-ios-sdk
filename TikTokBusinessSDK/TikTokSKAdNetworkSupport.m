//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokSKAdNetworkSupport.h"
#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokAppEventUtility.h"
#import "TikTokBusinessSDKMacros.h"
#import <StoreKit/SKAdNetwork.h>
#import "TikTokLogger.h"
#import "TikTokFactory.h"
#import "TikTokTypeUtility.h"
#import "TikTokBusiness.h"
#import "TikTokBusiness+private.h"
#import "TikTokAppEvent.h"
#import "TikTokSKAdNetworkRuleEvent.h"
#import "TikTokCurrencyUtility.h"
#import "TikTokBaseEventPersistence.h"
#import "TikTokSKANEventPersistence.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

static const long long firstWindowEnds = 172800000;
static const long long secondWindowEnds = 604800000;
static const long long thirdWindowEnds = 3024000000;

@interface TikTokSKAdNetworkSupport()

@property (nonatomic, strong, readwrite) Class skAdNetworkClass;
@property (nonatomic, assign, readwrite) SEL skAdNetworkRegisterAppForAdNetworkAttribution;
@property (nonatomic, assign, readwrite) SEL skAdNetworkUpdateConversionValue;
@property (nonatomic, strong) TikTokLogger *logger;

@end


@implementation TikTokSKAdNetworkSupport

+ (TikTokSKAdNetworkSupport *)sharedInstance
{
    static TikTokSKAdNetworkSupport *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[TikTokSKAdNetworkSupport alloc]init];
    });
    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _currentConversionValue = 0;
        self.skAdNetworkClass = NSClassFromString(@"SKAdNetwork");
        self.skAdNetworkRegisterAppForAdNetworkAttribution = NSSelectorFromString(@"registerAppForAdNetworkAttribution");
        self.skAdNetworkUpdateConversionValue = NSSelectorFromString(@"updateConversionValue:");
        self.logger = [TikTokFactory getLogger];
    }
    return self;
}

- (void)registerAppForAdNetworkAttribution
{
    if (@available(iOS 14.0, *)) {
//        NSLog(@"App registered for ad network attribution");
        ((id (*)(id, SEL))[self.skAdNetworkClass methodForSelector:self.skAdNetworkRegisterAppForAdNetworkAttribution])(self.skAdNetworkClass, self.skAdNetworkRegisterAppForAdNetworkAttribution);
    }
}

- (void)updateConversionValue:(NSInteger)conversionValue
{
    // Equivalent call: [SKAdNetwork updateConversionValue:conversionValue]
    if (@available(iOS 14.0, *)) {        
        ((id (*)(id, SEL, NSInteger))[self.skAdNetworkClass methodForSelector:self.skAdNetworkUpdateConversionValue])(self.skAdNetworkClass, self.skAdNetworkUpdateConversionValue, conversionValue);
    }
}

- (void)matchEventToSKANConfig:(NSString *)eventName withValue:(nullable NSString *)value currency:(nullable NSString *)currency
{
    NSInteger currentWindow = [self getConversionWindowForTimestamp:[TikTokAppEventUtility getCurrentTimestamp]];
    if (currentWindow == -1) {
        return;
    }
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *eventValue = [formatter numberFromString:value];
    // Persist current event
    [[TikTokSKANEventPersistence persistence] persistSKANEventWithName:eventName value:eventValue currency:currency];
    
    if (TTCheckValidString(currency)) {
        eventValue = [[TikTokCurrencyUtility sharedInstance] exchangeAmount:eventValue fromCurrency:currency toCurrency:[TikTokSKAdNetworkConversionConfiguration sharedInstance].currency shouldReport:YES];
    }
    
    NSUserDefaults *defaults = [TikTokDefaults storage];
    id dicObj = [defaults objectForKey:TTAccumulatedSKANValuesKey];
    NSMutableDictionary *accumulatedValues = [NSMutableDictionary dictionary];
    NSNumber *accumulatedValue = nil;
    if ([dicObj isKindOfClass:[NSDictionary class]]) {
        accumulatedValues = [(NSDictionary *)dicObj mutableCopy];
        accumulatedValue = [accumulatedValues objectForKey:eventName];
    }
    eventValue = [NSNumber numberWithDouble:[accumulatedValue doubleValue] + [eventValue doubleValue]];
    [TikTokTypeUtility dictionary:accumulatedValues setObject:eventValue forKey:eventName];
    [defaults setObject:accumulatedValues.copy forKey:TTAccumulatedSKANValuesKey];
    [defaults synchronize];
    
    NSArray *windows = [TikTokSKAdNetworkConversionConfiguration sharedInstance].conversionValueWindows;
    
    for (TikTokSKAdNetworkWindow * window in windows) {
        if (currentWindow == window.postbackIndex) {
            NSInteger fineValue = [[defaults objectForKey:TTLatestFineValueKey] integerValue];
            NSString *coarseValue = [defaults objectForKey:TTLatestCoarseValueKey];
            if (!TTCheckValidString(coarseValue)) {
                coarseValue = @"low";
            }
            BOOL shouldLock = NO;
            BOOL shouldUpdateFine = NO;
            BOOL shouldUpdateCoarse = NO;
            NSArray *fineRules = window.fineValueRules;
            for (TikTokSKAdNetworkRule *rule in fineRules) {
                for (TikTokSKAdNetworkRuleEvent *ruleEvent in rule.eventFunnel) {
                    if ([eventName isEqualToString:ruleEvent.eventName]) {
                        BOOL valueMatched = ([eventValue doubleValue] > [ruleEvent.minRevenue doubleValue]) || ([ruleEvent.minRevenue doubleValue] == 0 && [ruleEvent.maxRevenue doubleValue] == 0);
                        ruleEvent.isMatched = valueMatched;
                        if ([rule isMatched] && !shouldUpdateFine) {
                            fineValue = rule.fineConversionValue;
                            [defaults setObject:@(fineValue) forKey:TTLatestFineValueKey];
                            [defaults synchronize];
                            shouldUpdateFine = YES;
                            break;
                        }
                    }
                }
            }
            NSArray *coarseRules = window.coarseValueRules;
            for (TikTokSKAdNetworkRule *rule in coarseRules) {
                for (TikTokSKAdNetworkRuleEvent *ruleEvent in rule.eventFunnel) {
                    if ([eventName isEqualToString:ruleEvent.eventName]) {
                        BOOL valueMatched = ([eventValue doubleValue] > [ruleEvent.minRevenue doubleValue]) || ([ruleEvent.minRevenue doubleValue] == 0 && [ruleEvent.maxRevenue doubleValue] == 0);
                        ruleEvent.isMatched = valueMatched;
                        if ([rule isMatched] && !shouldUpdateCoarse) {
                            coarseValue = rule.coarseConversionValue;
                            [defaults setObject:coarseValue forKey:TTLatestCoarseValueKey];
                            [defaults synchronize];
                            shouldUpdateCoarse = YES;
                            break;
                        }
                    }
                }
            }
            
            if (shouldUpdateFine || shouldUpdateCoarse) {
                [self TTUpdateConversionValue:fineValue coarseValue:coarseValue lockWindow:shouldLock completionHandler:^(NSError *error) {
                    NSMutableDictionary *skanUpdateCVMeta = @{
                        @"fine": @(fineValue),
                        @"coarse": coarseValue,
                        @"lock_window": @(shouldLock),
                        @"event_name": eventName,
                        @"value": eventValue ?: @(0),
                        @"window": @(currentWindow),
                    }.mutableCopy;
                    if (error) {
                        [skanUpdateCVMeta setValue:@(NO) forKey:@"success"];
                        [skanUpdateCVMeta setValue:@(error.code) forKey:@"code"];
                        [skanUpdateCVMeta setValue:error.localizedDescription forKey:@"description"];
                    } else {
                        [skanUpdateCVMeta setValue:@(YES) forKey:@"success"];
                    }
                    NSDictionary *monitorSkanUpdateCVProperties = @{
                        @"monitor_type": @"metric",
                        @"monitor_name": @"skan_update_cv",
                        @"meta": skanUpdateCVMeta.copy
                    };
                    TikTokAppEvent *skanUpdateCVEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorSkanUpdateCVProperties withType:@"monitor"];
                    [[TikTokBusiness getEventLogger] addEvent:skanUpdateCVEvent];
                }];
            }
            break;
        }
    }
}

- (NSInteger)getConversionWindowForTimestamp:(long long)timeStamp {
    if (@available(iOS 16.1, *)) {
        //Supports SKAN 4.0.
        NSUserDefaults *defaults = [TikTokDefaults storage];
        long long firstLaunchTime = [[defaults objectForKey:TTUserDefaultsKey_firstLaunchTime] longLongValue];
        long long timePassed = timeStamp - firstLaunchTime;
        if (timePassed < 0 || timePassed >= thirdWindowEnds) {
            return -1;
        } else if (timePassed >= secondWindowEnds) {
            return 2;
        } else if (timePassed >= firstWindowEnds) {
            return 1;
        } else {
            return 0;
        }
    } else if (@available(iOS 14.0, *)) {
        // Supports only SKAN 3.0. Match by rules in window 1.
        return 0;
    } else {
        // Does not support SKAN.
        return -1;
    }
}

- (void)TTUpdateConversionValue:(NSInteger)conversionValue
                    coarseValue:(NSString *)coarseValue
                     lockWindow:(BOOL)lockWindow
              completionHandler:(void (^)(NSError * _Nullable error))completionHandler {
    if (@available(iOS 16.1, *)) {
        //Supports SKAN 4.0.
        [SKAdNetwork updatePostbackConversionValue:conversionValue coarseValue:coarseValue lockWindow:lockWindow completionHandler:^(NSError * _Nullable error) {
            if (error) {
                [self.logger error:@"Call to SKAdNetwork's updatePostbackConversionValue:coarseValue:lockWindow:completionHandler: method with conversion value: %d, coarse value: %@, lock window: %d failed\nDescription: %@", conversionValue, coarseValue, lockWindow, error.localizedDescription];
            } else {
                [self.logger debug:@"Called SKAdNetwork's updatePostbackConversionValue:coarseValue:lockWindow:completionHandler: method with conversion value: %d, coarse value: %@, lock window: %d", conversionValue, coarseValue, lockWindow];
            }
            if (completionHandler) {
                completionHandler(error);
            }
        }];
    } else if (@available(iOS 15.4, *)) {
        // Supports only SKAN 3.0 but has new API available.
        [SKAdNetwork updatePostbackConversionValue:conversionValue completionHandler:^(NSError * _Nullable error) {
            if (error) {
                [self.logger error:@"Call to updatePostbackConversionValue:completionHandler: method with conversion value: %d failed\nDescription: %@", conversionValue, error.localizedDescription];
            } else {
                [self.logger debug:@"Called SKAdNetwork's updatePostbackConversionValue:completionHandler: method with conversion value: %d", conversionValue];
            }
            if (completionHandler) {
                completionHandler(error);
            }
        }];
    } else if (@available(iOS 14.0, *)) {
        // Supports only SKAN 3.0.
        [self updateConversionValue:conversionValue];
    } else {
        [self.logger error:@"SKAdNetwork API not available on this iOS version"];
    }
}

- (void)matchPersistedSKANEventsInWindow:(TikTokSKAdNetworkWindow *)window {
    NSArray *skanEvents = [[TikTokSKANEventPersistence persistence] retrievePersistedEvents];
    if (TTCheckValidArray(skanEvents)) {
        for (NSDictionary *eventDict in skanEvents) {
            if (TTCheckValidDictionary(eventDict)) {
                NSString *eventName = [eventDict objectForKey:@"eventName"];
                NSNumber *value = [eventDict objectForKey:@"value"];
                NSString *currency = [eventDict objectForKey:@"currency"];
                if (TTCheckValidString(currency)) {
                    value = [[TikTokCurrencyUtility sharedInstance] exchangeAmount:value fromCurrency:currency toCurrency:[TikTokSKAdNetworkConversionConfiguration sharedInstance].currency shouldReport:NO];
                }
                for (TikTokSKAdNetworkRule *fineRule in window.fineValueRules) {
                    for (TikTokSKAdNetworkRuleEvent *ruleEvent in fineRule.eventFunnel) {
                        if (ruleEvent.isMatched) continue;
                        if ([eventName isEqualToString:ruleEvent.eventName]) {
                            BOOL valueMatched = ([value doubleValue] > [ruleEvent.minRevenue doubleValue] && [value doubleValue] <= [ruleEvent.maxRevenue doubleValue]) || ([ruleEvent.minRevenue doubleValue] == 0 && [ruleEvent.maxRevenue doubleValue] == 0);
                            ruleEvent.isMatched = valueMatched;
                        }
                    }
                }
                for (TikTokSKAdNetworkRule *coarseRule in window.coarseValueRules) {
                    for (TikTokSKAdNetworkRuleEvent *ruleEvent in coarseRule.eventFunnel) {
                        if (ruleEvent.isMatched) continue;
                        if ([eventName isEqualToString:ruleEvent.eventName]) {
                            BOOL valueMatched = ([value doubleValue] > [ruleEvent.minRevenue doubleValue] && [value doubleValue] <= [ruleEvent.maxRevenue doubleValue]) || ([ruleEvent.minRevenue doubleValue] == 0 && [ruleEvent.maxRevenue doubleValue] == 0);
                            ruleEvent.isMatched = valueMatched;
                        }
                    }
                }
            }
        }
    }
    
}



@end
