//
//  TikTokSKAdNetworkSupportTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2024/7/1.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TikTokSKAdNetworkSupport.h"
#import "TikTokSKAdNetworkConversionConfiguration.h"
#import "TikTokCurrencyUtility.h"
#import "TikTokCurrencyUtility.h"

@interface TikTokSKAdNetworkSupportTests : XCTestCase

@end

@implementation TikTokSKAdNetworkSupportTests

- (void)setUp {
    [super setUp];
    NSString *configStr = @"{\"currency\":\"USD\",\"postbacks\":[{\"coarse\":[{\"conversion_value\":\"low\",\"event_funnel\":[{\"event_name\":\"active\",\"event_name_report\":\"AppInstall\",\"event_value\":8,\"revenue_max\":0,\"revenue_min\":0}]},{\"conversion_value\":\"medium\",\"event_funnel\":[{\"event_name\":\"active_pay\",\"event_name_report\":\"Purchase\",\"event_value\":14,\"revenue_max\":3,\"revenue_min\":0}]},{\"conversion_value\":\"high\",\"event_funnel\":[{\"event_name\":\"active_pay\",\"event_name_report\":\"Purchase\",\"event_value\":14,\"revenue_max\":100,\"revenue_min\":3}]}],\"fine\":[{\"conversion_value\":\"0\",\"event_funnel\":[{\"event_name\":\"launch_app\",\"event_name_report\":\"LaunchAPP\",\"event_value\":129,\"revenue_max\":0,\"revenue_min\":0}]},{\"conversion_value\":\"1\",\"event_funnel\":[{\"event_name\":\"in_app_ad_impr\",\"event_name_report\":\"InAppADImpr\",\"event_value\":133,\"revenue_max\":0,\"revenue_min\":0}]},{\"conversion_value\":\"2\",\"event_funnel\":[{\"event_name\":\"in_app_ad_click\",\"event_name_report\":\"InAppADClick\",\"event_value\":132,\"revenue_max\":0,\"revenue_min\":0}]}],\"postback_index\":0},{\"coarse\":[{\"conversion_value\":\"high\",\"event_funnel\":[{\"event_name\":\"in_app_order\",\"event_name_report\":\"Checkout\",\"event_value\":20,\"revenue_max\":0,\"revenue_min\":0}]}],\"fine\":null,\"postback_index\":1}]}";
    NSData *configData = [configStr dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *configDic = [NSJSONSerialization JSONObjectWithData:configData options:NSJSONReadingMutableContainers error:&err];
    [[TikTokSKAdNetworkConversionConfiguration sharedInstance] configWithDict:configDic];
    [[TikTokCurrencyUtility sharedInstance] configWithDict:@{@"USD": @(1.0), @"CNY": @(7.1)}];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testMatch {
    [[TikTokSKAdNetworkSupport sharedInstance] matchEventToSKANConfig:@"Purchase" withValue:@"30" currency:@"USD"];
}

- (void)testExchange {
    XCTAssertTrue([[[TikTokCurrencyUtility sharedInstance] exchangeAmount:@(1) fromCurrency:@"USD" toCurrency:@"CNY" shouldReport:YES] doubleValue] == 7.1);
}

@end
