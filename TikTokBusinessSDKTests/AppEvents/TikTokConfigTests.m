//
//  TikTokConfigTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2024/5/16.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TikTokConfig.h"

@interface TikTokConfigTests : XCTestCase

@end

@implementation TikTokConfigTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testInit {
    TikTokConfig *config = [TikTokConfig configWithAccessToken:@"abc" appId:@"123" tiktokAppId:@"456"];
    XCTAssertEqual(@"abc", config.accessToken);
    XCTAssertEqual(@"123", config.appId);
    XCTAssertEqual(@"456", config.tiktokAppId);
}

- (void)testSwitches {
    TikTokConfig *config = [[TikTokConfig alloc] initWithAppId:@"123" tiktokAppId:@"456"];
    
    [config enableDebugMode];
    XCTAssertTrue(config.debugModeEnabled);
    [config disableSKAdNetworkSupport];
    XCTAssertFalse(config.SKAdNetworkSupportEnabled);
    [config disableAppTrackingDialog];
    XCTAssertTrue(config.appTrackingDialogSuppressed);
    [config disablePaymentTracking];
    XCTAssertFalse(config.paymentTrackingEnabled);
    [config disableRetentionTracking];
    XCTAssertFalse(config.retentionTrackingEnabled);
    [config enableLDUMode];
    XCTAssertTrue(config.LDUModeEnabled);
    [config disableLaunchTracking];
    XCTAssertFalse(config.launchTrackingEnabled);
    [config disableInstallTracking];
    XCTAssertFalse(config.installTrackingEnabled);
    [config disableAutomaticTracking];
    XCTAssertFalse(config.automaticTrackingEnabled);
    [config disableTracking];
    XCTAssertFalse(config.trackingEnabled);
}

@end
