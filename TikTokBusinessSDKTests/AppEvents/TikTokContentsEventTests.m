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

// Reproduces the "Invalid Price Field" (server error 40000) bug: a content item
// with no price serializes `price` to the literal string "(null)", which the
// events API rejects — dropping the whole flush batch.
- (void)testContentWithoutPriceOmitsPriceField {
    TikTokContentParams *content = [[TikTokContentParams alloc] init];
    content.contentId = @"sku_1";
    content.quantity = 1;
    // price intentionally left unset (nil)

    TikTokViewContentEvent *event = [[TikTokViewContentEvent alloc] init];
    [event setContents:@[content]];

    NSArray *contents = (NSArray *)[event.properties objectForKey:@"contents"];
    NSDictionary *first = contents.firstObject;
    XCTAssertNotNil(first, @"Event should carry a serialized content item");
    XCTAssertFalse([first[@"price"] isEqual:@"(null)"], @"nil price must not serialize to the string \"(null)\"");
    XCTAssertNil(first[@"price"], @"price key should be omitted when no price is set");
}

// A real price must serialize as a number (matching `quantity`), not a string.
- (void)testContentPriceSerializesAsNumber {
    TikTokContentParams *content = [[TikTokContentParams alloc] init];
    content.contentId = @"sku_1";
    content.price = @(1.1);
    content.quantity = 1;

    TikTokViewContentEvent *event = [[TikTokViewContentEvent alloc] init];
    [event setContents:@[content]];

    NSDictionary *first = [(NSArray *)[event.properties objectForKey:@"contents"] firstObject];
    XCTAssertTrue([first[@"price"] isKindOfClass:[NSNumber class]], @"price should serialize as a number, not a string");
    XCTAssertEqualObjects(first[@"price"], @(1.1), @"price should preserve its numeric value");
}

@end
