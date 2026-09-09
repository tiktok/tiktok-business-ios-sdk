//
//  TikTokConsentTests.m
//  TikTokBusinessSDKTests
//
//  Created by TikTok on 2026/9/9.
//  Copyright © 2026 TikTok. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TikTokBusiness.h"
#import "TikTokConfig.h"
#import "TikTokAppEvent.h"
#import "TikTokBaseEvent.h"
#import "TikTokBaseEventPersistence.h"

@interface TikTokConsentTests : XCTestCase

@end

@implementation TikTokConsentTests

- (void)setUp {
    [super setUp];
    [TikTokBusiness resetInstance];
    [[TikTokAppEventPersistence persistence] clearEvents];
    [[TikTokMonitorEventPersistence persistence] clearEvents];
}

- (void)tearDown {
    [[TikTokAppEventPersistence persistence] clearEvents];
    [[TikTokMonitorEventPersistence persistence] clearEvents];
    [TikTokBusiness resetInstance];
    [super tearDown];
}

#pragma mark - Helpers

/// Tracking is disabled in the config so that no request is made from the unit test.
- (TikTokConfig *)configDiscardingEventsWhileTrackingDisabled {
    TikTokConfig *config = [TikTokConfig configWithAccessToken:@"token" appId:@"123456" tiktokAppId:@"7891011"];
    config.discardEventsWhileTrackingDisabled = YES;
    [config disableTracking];
    [config disableAutomaticTracking];
    [config disableSKAdNetworkSupport];
    return config;
}

- (TikTokAppEvent *)seededEvent {
    return [[TikTokAppEvent alloc] initWithEventName:@"TestEvent"];
}

/// The event logger persists on its own serial queue, so give it time to land on disk.
- (void)settle {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
}

#pragma mark - Tests

- (void)testClearPersistedEventsPurgesBothStores {
    [[TikTokAppEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    [[TikTokMonitorEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 1);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 1);

    [TikTokBusiness clearPersistedEvents];
    [self settle];

    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 0);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);
}

- (void)testConfigDefaultsToCachingEventsWhileTrackingIsDisabled {
    TikTokConfig *config = [TikTokConfig configWithAccessToken:@"token" appId:@"123456" tiktokAppId:@"7891011"];
    XCTAssertFalse(config.discardEventsWhileTrackingDisabled);

    config.discardEventsWhileTrackingDisabled = YES;
    XCTAssertTrue(config.discardEventsWhileTrackingDisabled);
}

- (void)testDefaultBehaviourKeepsCachingAndPurgingStaysOptIn {
    [TikTokBusiness setTrackingEnabled:NO];
    XCTAssertFalse([TikTokBusiness isTrackingEnabled]);

    // Without the opt-in flag, events are still cached locally while tracking is disabled
    // and disabling tracking does not purge anything.
    [[TikTokAppEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    [[TikTokMonitorEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 1);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 1);

    [TikTokBusiness setTrackingEnabled:NO];
    [self settle];

    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 1);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 1);

    [TikTokBusiness setTrackingEnabled:YES];
}

- (void)testWithdrawalDiscardsNewEventsAndPurgesPersistedOnes {
    [[TikTokAppEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    [[TikTokMonitorEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 1);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 1);

    [TikTokBusiness initializeSdk:[self configDiscardingEventsWhileTrackingDisabled]];
    [self settle];
    XCTAssertFalse([TikTokBusiness isTrackingEnabled]);
    // The monitor events emitted by initialization are dropped, nothing new is persisted.
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 1);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 1);

    // A withdrawal purges what is already on disk.
    [TikTokBusiness setTrackingEnabled:NO];
    [self settle];
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 0);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);

    // Events tracked after the withdrawal never reach the stores.
    [TikTokBusiness trackTTEvent:[TikTokBaseEvent eventWithName:@"TestEvent"]];
    [[TikTokBusiness getInstance] reportTikTokAppEvent:[self seededEvent]];
    XCTAssertFalse([[TikTokAppEventPersistence persistence] persistEvents:@[[self seededEvent]]]);
    XCTAssertFalse([[TikTokMonitorEventPersistence persistence] persistEvents:@[[self seededEvent]]]);
    [self settle];

    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 0);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);
}

@end
