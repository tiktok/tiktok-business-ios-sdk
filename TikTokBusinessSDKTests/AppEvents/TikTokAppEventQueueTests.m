//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "TikTokBusiness.h"
#import "TikTokAppEvent.h"
#import "TikTokAppEventQueue.h"
#import "TikTokRequestHandler.h"

@interface TikTokAppEventQueue()
@property (nonatomic, strong, nullable) TikTokRequestHandler *requestHandler;

- (void)flushOnMainQueue:(NSMutableArray *)eventsToBeFlushed
               forReason:(TikTokAppEventsFlushReason)flushReason;
@end

@interface TikTokAppEventQueueTests : XCTestCase

@property (nonatomic, strong) TikTokBusiness *tiktokBusiness;
@property (nonatomic, strong) TikTokConfig *config;
@property (nonatomic, strong) TikTokAppEventQueue *queue;

@end

@implementation TikTokAppEventQueueTests

- (void)setUp {
    [super setUp];
    TikTokConfig *config = [[TikTokConfig alloc] initWithAppId: @"123" tiktokAppId: @"456"];
    [TikTokBusiness initializeSdk:config];
    TikTokBusiness *tiktokBusiness = [TikTokBusiness getInstance];
    self.tiktokBusiness = OCMPartialMock(tiktokBusiness);
    OCMStub([self.tiktokBusiness isRemoteSwitchOn]).andReturn(YES);
    OCMStub([self.tiktokBusiness isGlobalConfigFetched]).andReturn(YES);
    
    TikTokAppEventQueue *queue = [[TikTokAppEventQueue alloc] initWithConfig:config];
    self.config = OCMPartialMock(config);
    self.queue = OCMPartialMock(queue);
    
    TikTokRequestHandler *requestHandler = OCMClassMock([TikTokRequestHandler class]);
    OCMStub(self.queue.requestHandler).andReturn(requestHandler);
    
    XCTAssertTrue(self.queue.eventQueue.count == 0, @"Queue should be empty");
}

- (void)tearDown {
    [super tearDown];
    [TikTokBusiness resetInstance];
}

- (void)testIdentify {
    [TikTokBusiness identifyWithExternalID:@"aaa" externalUserName:@"bbb" phoneNumber:@"ccc" email:@"ddd"];
}

- (void)testLogout {
    [TikTokBusiness logout];
}

- (void)testAddEvent {
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:@"LaunchAPP"];
    
    for (int i = 0; i < 99; i++)
    {
        [self.queue addEvent:event];
    }
    
    XCTAssertTrue(self.queue.eventQueue.count == 99, @"Queue should have length of 99");
    
    [self.queue addEvent:event];
    
    // expect events to flush after 100 events added to queue
    OCMVerify([self.queue flush:TikTokAppEventsFlushReasonEventThreshold]);
}

- (void)testFlush {
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:@"LaunchAPP"];
    [self.queue addEvent:event];
    XCTAssertTrue(self.queue.eventQueue.count == 1, @"Queue should have length of 1");
    [self.queue flush:TikTokAppEventsFlushReasonExplicitlyFlush];
    XCTAssertTrue(self.queue.eventQueue.count == 0, @"Queue should have length of 0");
}

@end
