//
//  TikTokContentsEventTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2024/5/13.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TikTokContentsEvent.h"

@interface TikTokContentsEventTests : XCTestCase

@end

@implementation TikTokContentsEventTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSetDescription {
    NSString *description = @"TEST_DESCRIPTION";
    TikTokContentsEvent *event = [[TikTokContentsEvent alloc] init];
    [event setDescription:description];
    XCTAssertTrue([description isEqualToString:(NSString *)[event.properties objectForKey:@"description"]], @"Event should have correct description");
    XCTAssertTrue(event.properties.count == 1, @"Event should have 1 property");
}

- (void)testSetCurrency {
    TTCurrency currency = TTCurrencyUSD;
    TikTokContentsEvent *event = [[TikTokContentsEvent alloc] init];
    [event setCurrency:currency];
    XCTAssertTrue([currency isEqualToString:(NSString *)[event.properties objectForKey:@"currency"]], @"Event should have correct currency");
    XCTAssertTrue(event.properties.count == 1, @"Event should have 1 property");
}

- (void)testSetValue {
    NSString *value = @"TEST_VALUE";
    TikTokContentsEvent *event = [[TikTokContentsEvent alloc] init];
    [event setValue:value];
    XCTAssertTrue([value isEqualToString:(NSString *)[event.properties objectForKey:@"value"]], @"Event should have correct value");
    XCTAssertTrue(event.properties.count == 1, @"Event should have 1 property");
}

- (void)testSetContentType {
    NSString *type = @"TEST_TYPE";
    TikTokContentsEvent *event = [[TikTokContentsEvent alloc] init];
    [event setContentType:type];
    XCTAssertTrue([type isEqualToString:(NSString *)[event.properties objectForKey:@"content_type"]], @"Event should have correct description");
    XCTAssertTrue(event.properties.count == 1, @"Event should have 1 property");
}

- (void)testSetContentId {
    NSString *contentId = @"TEST_ID";
    TikTokContentsEvent *event = [[TikTokContentsEvent alloc] init];
    [event setContentId:contentId];
    XCTAssertTrue([contentId isEqualToString:(NSString *)[event.properties objectForKey:@"content_id"]], @"Event should have correct description");
    XCTAssertTrue(event.properties.count == 1, @"Event should have 1 property");
}

@end
