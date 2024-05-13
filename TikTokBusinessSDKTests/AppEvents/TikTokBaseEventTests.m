//
//  TikTokBaseEventTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2024/5/13.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TikTokBaseEvent.h"

@interface TikTokBaseEventTests : XCTestCase

@end

@implementation TikTokBaseEventTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testInit {
    NSString *eventName = @"TEST_EVENT_NAME";
    
    TikTokBaseEvent *event = [[TikTokBaseEvent alloc] initWithEventName:eventName];
    
    XCTAssertTrue(eventName == event.eventName, @"Event should initialize correctly with event name");
    XCTAssertTrue(event.properties.count == 0, @"Event should not have any properties");
}

- (void)testInitWithId{
    NSString *eventName = @"TEST_EVENT_NAME";
    NSString *eventId = @"TEST_EVENT_ID";
    TikTokBaseEvent *event = [[TikTokBaseEvent alloc] initWithEventName:eventName eventId:eventId];
    
    XCTAssertTrue(eventName == event.eventName, @"Event should initialize correctly with event name");
    XCTAssertTrue(eventId == event.eventId, @"Event should initialize correctly with event Id");
}

- (void)testInitWithPropertiesAndId{
    NSString *eventName = @"TEST_EVENT_NAME";
    NSString *eventId = @"TEST_EVENT_ID";
    NSDictionary *properties = @{
        @"key_1":@"value_1",
        @"key_2":@"value_2"
    };
    TikTokBaseEvent *event = [[TikTokBaseEvent alloc] initWithEventName:eventName properties:properties eventId:eventId];
    
    XCTAssertTrue(eventName == event.eventName, @"Event should initialize correctly with event name");
    XCTAssertTrue(eventId == event.eventId, @"Event should initialize correctly with event Id");
    XCTAssertTrue(event.properties.count == 2, @"Event should have 2 properties");
    
    [event addPropertyWithKey:@"key_3" value:@"value_3"];
    XCTAssertTrue(event.properties.count == 3, @"Event should have 3 properties");
}

@end
