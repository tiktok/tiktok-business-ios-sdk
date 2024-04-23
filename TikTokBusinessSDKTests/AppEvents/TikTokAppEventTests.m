//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <XCTest/XCTest.h>
#import "TikTokAppEvent.h"

@interface TikTokAppEventTests : XCTestCase

@end

@implementation TikTokAppEventTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testInit {
    NSString *eventName = @"TEST_EVENT_NAME";
    
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:eventName];
    
    XCTAssertTrue(eventName == event.eventName, @"Event should initialize correctly with event name");
    
    XCTAssertTrue(event.properties.count == 0, @"Event should not have any properties");
}

- (void)testInitWithProperties{
    NSString *eventName = @"TEST_EVENT_NAME";
    NSDictionary *properties = @{
        @"key_1":@"value_1",
        @"key_2":@"value_2"
    };
    
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:eventName withProperties:properties];
    
    XCTAssertTrue(eventName == event.eventName, @"Event should initialize correctly with event name");
    
    XCTAssertTrue(event.properties.count == 2, @"Event should have 2 properties");
}

@end
