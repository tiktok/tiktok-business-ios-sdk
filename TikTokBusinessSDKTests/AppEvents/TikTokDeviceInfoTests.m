//
//  TikTokDeviceInfoTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2024/5/14.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TikTokDeviceInfo.h"

@interface TikTokDeviceInfoTests : XCTestCase

@end

@implementation TikTokDeviceInfoTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testInit {
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfoWithSdkPrefix:@""];
    XCTAssertNotNil(deviceInfo);
}


- (void)testFallbackUserAgent {
    TikTokDeviceInfo *deviceInfo = [TikTokDeviceInfo deviceInfoWithSdkPrefix:@""];
    XCTAssertNotNil([deviceInfo fallbackUserAgent]);
}


@end
