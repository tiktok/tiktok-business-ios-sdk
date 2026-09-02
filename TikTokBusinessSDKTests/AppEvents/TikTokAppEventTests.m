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
    
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:eventName withProperties:properties withEventID:@""];
    
    XCTAssertTrue(eventName == event.eventName, @"Event should initialize correctly with event name");
    
    XCTAssertTrue(event.properties.count == 2, @"Event should have 2 properties");
}

// The event timestamp must be ISO 8601 regardless of the user's 24-Hour Time
// setting. A fixed-format NSDateFormatter without the en_US_POSIX locale lets
// that setting rewrite "HH", producing e.g. "2026-09-02T3:33:07 PMZ".
- (void)testTimestampIsISO8601UnderA12HourClock {
    NSString *pattern = @"^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$";
    NSRegularExpression *iso8601 = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                             options:0
                                                                               error:nil];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id previous = [defaults objectForKey:@"AppleICUForce12HourTime"];
    [defaults setBool:YES forKey:@"AppleICUForce12HourTime"];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSCurrentLocaleDidChangeNotification
                                                        object:nil];

    NSString *timestamp = [[[TikTokAppEvent alloc] initWithEventName:@"TEST_EVENT_NAME"] timestamp];

    if (previous == nil) {
        [defaults removeObjectForKey:@"AppleICUForce12HourTime"];
    } else {
        [defaults setObject:previous forKey:@"AppleICUForce12HourTime"];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NSCurrentLocaleDidChangeNotification
                                                        object:nil];

    NSUInteger matches = [iso8601 numberOfMatchesInString:timestamp
                                                  options:0
                                                    range:NSMakeRange(0, timestamp.length)];
    XCTAssertEqual(matches, (NSUInteger)1,
                   @"Timestamp \"%@\" is not ISO 8601", timestamp);
}

@end
