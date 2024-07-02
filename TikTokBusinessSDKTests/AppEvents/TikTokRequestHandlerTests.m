//
//  TikTokRequestHandlerTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2024/6/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "TikTokRequestHandler.h"
#import "TikTokFactory.h"
#import "TikTokBusiness.h"
#import "TikTokAppEvent.h"

@interface TikTokRequestHandlerTests : XCTestCase

@property (nonatomic, strong) TikTokBusiness *tiktokBusiness;
@property (nonatomic, strong) TikTokRequestHandler *requestHandler;
@property (nonatomic, strong) TikTokConfig *config;

@end

@implementation TikTokRequestHandlerTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [super setUp];
    TikTokRequestHandler *requestHanler = [TikTokFactory getRequestHandler];
    self.requestHandler = OCMPartialMock(requestHanler);
    
    TikTokConfig *config = [[TikTokConfig alloc] initWithAppId: @"123" tiktokAppId: @"456"];
    self.config = OCMPartialMock(config);
    
    TikTokBusiness *tiktokBusiness = [TikTokBusiness getInstance];
    self.tiktokBusiness = OCMPartialMock(tiktokBusiness);
}

- (void)tearDown {
    [super tearDown];
    self.requestHandler = nil;
}

- (void)testGetRemoteSwitchWithCompletionHandler {
    XCTestExpectation *expectation = [self expectationWithDescription:@"remote config fetched"];
    [self.requestHandler getRemoteSwitch:self.config withCompletionHandler:^(BOOL isRemoteSwitchOn, NSDictionary * _Nonnull globalConfig) {
        XCTAssertTrue(isRemoteSwitchOn);
        XCTAssertNotNil(globalConfig);
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {}
    ];
}

//- (void)testSendBatchRequestwithConfig {
//    XCTestExpectation *expectation = [self expectationWithDescription:@"batch sent"];
//    NSString *eventName = @"TEST_EVENT_NAME";
//    NSDictionary *properties = @{
//        @"key_1":@"value_1",
//        @"key_2":@"value_2"
//    };
//    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:eventName withProperties:properties];
//    [self.requestHandler sendBatchRequest:@[event] withConfig:self.config];
//    [expectation fulfill];
//    XCTAssert(1 == 1, @"Network request sent successfully");
//}

//- (void)testSendMonitorRequestwithConfig {
//    NSDictionary *monitorTestProperties = @{
//        @"monitor_type": @"metric",
//        @"monitor_name": @"monitor_test",
//        @"meta": @{
//            @"test_key": @"test_value"
//        }
//    };
//    TikTokAppEvent *monitorTestEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:monitorTestProperties withType:@"monitor"];
//    
//    [self.requestHandler sendMonitorRequest:@[monitorTestEvent] withConfig:self.config];
//    XCTAssert(1 == 1, @"Network request sent successfully");
//}

@end
