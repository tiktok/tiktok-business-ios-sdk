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

#import "TikTokBusiness+private.h"
#import "TikTokRequestHandler.h"
#import "TikTokFactory.h"
#import "TikTokDatabase.h"
#import "TTSDKCrash.h"
#import "TTSDKCrashReportStore.h"
#import "TTSDKCrashConfiguration+Private.h"
#import "TTSDKCrashReportStoreC.h"

// A deterministic transport: no test contacts TikTok and responses can arrive
// after cancellation, just as an already-running NSURLSession callback can.
@interface TTConsentTask : NSURLSessionDataTask
@property (nonatomic) BOOL resumed;
@property (nonatomic) BOOL cancelled;
@property (nonatomic, copy) void (^result)(NSData *, NSURLResponse *, NSError *);
@end
@implementation TTConsentTask
- (void)resume { self.resumed = YES; }
- (void)cancel { self.cancelled = YES; }
@end

@interface TTConsentSession : NSURLSession
@property (nonatomic, strong) NSMutableArray<TTConsentTask *> *requests;
@end
@implementation TTConsentSession
- (instancetype)init { self = [super init]; if (self) _requests = [NSMutableArray new]; return self; }
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    TTConsentTask *task = [TTConsentTask new];
    task.result = completionHandler;
    [self.requests addObject:task];
    return task;
}
@end

@interface TikTokConsentTests : XCTestCase
@property (nonatomic, strong) TTConsentSession *session;
@property (nonatomic, strong) NSURLSession *originalSession;
@end

@implementation TikTokConsentTests

- (void)setUp {
    [super setUp];
    [TikTokBusiness resetInstance];
    self.originalSession = [TikTokFactory getRequestHandler].session;
    self.session = [TTConsentSession new];
    [TikTokFactory getRequestHandler].session = self.session;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HasBeenInitialized"];
    [[TikTokAppEventPersistence persistence] clearEvents];
    [[TikTokMonitorEventPersistence persistence] clearEvents];
}

- (void)tearDown {
    [TikTokBusiness setTrackingEnabled:NO];
    [self purgeAndWait];
    [[TikTokFactory getRequestHandler] cancelPendingRequests];
    [TikTokFactory getRequestHandler].session = self.originalSession;
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


- (void)purgeAndWait {
    XCTestExpectation *purged = [self expectationWithDescription:@"native store purge acknowledged"];
    [TikTokBusiness clearPersistedEventsWithCompletion:^(BOOL success) {
        XCTAssertTrue(success);
        XCTAssertTrue(NSThread.isMainThread);
        [purged fulfill];
    }];
    [self waitForExpectations:@[purged] timeout:3];
}

- (TikTokConfig *)activeConsentConfig {
    TikTokConfig *config = [TikTokConfig configWithAccessToken:@"test-token" appId:@"123456" tiktokAppId:@"7891011"];
    config.discardEventsWhileTrackingDisabled = YES;
    [config disablePaymentTracking];
    [config disableSKAdNetworkSupport];
    [config disableAutoEnhancedDataPostbackEvent];
    return config;
}

- (void)completeTask:(TTConsentTask *)task status:(NSInteger)status config:(NSDictionary *)config {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"code":@0, @"data":@{@"business_sdk_config":config ?: @{}}} options:0 error:nil];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.invalid/config"] statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
    task.result(data, response, nil);
}

- (void)testLateConfigResponseCannotRetryOrMutateAfterWithdrawalAndReconsent {
    [TikTokBusiness initializeSdk:[self activeConsentConfig]];
    XCTAssertEqual(self.session.requests.count, 2);
    TTConsentTask *oldConfig = self.session.requests.firstObject;
    [TikTokBusiness setTrackingEnabled:NO];
    XCTAssertTrue(oldConfig.cancelled);
    [self purgeAndWait];
    [TikTokBusiness setTrackingEnabled:YES];
    NSUInteger requestCount = self.session.requests.count;
    [self completeTask:oldConfig status:500 config:@{@"enable_sdk":@YES}];
    XCTAssertEqual(self.session.requests.count, requestCount, @"An old error callback must not retry in the new consent generation");
    XCTAssertFalse([TikTokBusiness getInstance].isGlobalConfigFetched);
    [self completeTask:oldConfig status:200 config:@{@"enable_sdk":@YES}];
    XCTAssertFalse([TikTokBusiness getInstance].isGlobalConfigFetched, @"An old success must not apply global settings after reconsent");
}

- (void)testAllTransportEntrypointsStaySilentWhileWithdrawn {
    TikTokConfig *config = [self activeConsentConfig];
    [TikTokBusiness initializeSdk:config];
    [TikTokBusiness setTrackingEnabled:NO];
    [self purgeAndWait];
    NSUInteger count = self.session.requests.count;
    TikTokRequestHandler *handler = [TikTokFactory getRequestHandler];
    [handler getRemoteSwitch:config isRetry:YES withCompletionHandler:^(BOOL on, NSDictionary *global) { XCTFail(@"No callback expected"); }];
    [handler getDebugMode:config withCompletionHandler:^(NSDictionary *global, NSError *error) { XCTFail(@"No callback expected"); }];
    [handler sendBatchRequest:@[[self seededEvent]] withConfig:config];
    TikTokAppEvent *monitor = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:@{} withType:@"monitor"];
    [handler sendMonitorRequest:@[monitor] withConfig:config];
    [handler fetchDeferredDeeplinkWithConfig:config completion:^(NSURL *url, NSError *error) { XCTFail(@"No callback expected"); }];
    XCTAssertEqual(self.session.requests.count, count);
}

- (void)testQueuedFlushAndWritesCannotCrossImmediateReconsent {
    [TikTokBusiness initializeSdk:[self activeConsentConfig]];
    [self purgeAndWait];
    [TikTokBusiness getInstance].isGlobalConfigFetched = YES;
    TikTokEventLogger *logger = [TikTokBusiness getEventLogger];
    dispatch_queue_t queue = [logger valueForKey:@"loggerQueue"];
    [[TikTokAppEventPersistence persistence] persistEvents:@[[self seededEvent]]];
    dispatch_suspend(queue);
    [logger flush:TikTokAppEventsFlushReasonExplicitlyFlush];
    [logger addEvent:[self seededEvent]];
    [TikTokBusiness setTrackingEnabled:NO];
    // Intentionally use the legacy immediate API to prove the SDK generation gate
    // itself drops old queued work; the application additionally awaits the purge.
    [TikTokBusiness setTrackingEnabled:YES];
    NSUInteger count = self.session.requests.count;
    dispatch_resume(queue);
    [self purgeAndWait];
    XCTAssertEqual(self.session.requests.count, count);
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 0);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);
    XCTAssertTrue([TikTokBusiness isTrackingEnabled]);
    XCTAssertFalse([TikTokBusiness shouldDiscardEvents]);
    [logger addEvent:[self seededEvent]];
    dispatch_sync(queue, ^{});
    XCTAssertEqual([[TikTokAppEventPersistence persistence] eventsCount], 1, @"A fresh event must be persisted before flushing");
    TikTokDatabase *db = [[TikTokAppEventPersistence persistence] valueForKey:@"db"];
    NSArray *rows = [db queryTable:@"app_event_table" withWhere:@"sending = 0" orderBy:TTDBOrderByNone limit:TTDBLimitNone];
    XCTAssertEqual(rows.count, 1);
    NSError *decodeError = nil;
    id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:TikTokAppEvent.class fromData:rows.firstObject[@"event_data"] error:&decodeError];
    XCTAssertNotNil(decoded, @"Persisted events must decode: %@", decodeError);
    [logger flush:TikTokAppEventsFlushReasonExplicitlyFlush];
    XCTestExpectation *drained = [self expectationWithDescription:@"new-generation event flushed"];
    dispatch_async(queue, ^{ [drained fulfill]; });
    [self waitForExpectations:@[drained] timeout:3];
    XCTAssertEqual(self.session.requests.count, count + 1, @"Fresh consented events still transmit");
}

- (void)testRemotePaymentAndCrashSettingsCannotOverrideConsentModeLocalOptOut {
    [TikTokBusiness initializeSdk:[self activeConsentConfig]];
    [self completeTask:self.session.requests.firstObject status:200 config:@{
        @"enable_sdk":@YES, @"auto_track_Payment_enable":@YES,
        @"enable_ios_sk2_observe":@YES, @"crash_monitor_enable":@YES
    }];
    XCTAssertTrue([[[TikTokBusiness getInstance] valueForKey:@"automaticTrackingEnabled"] boolValue], @"The test must leave automatic installs enabled");
    XCTAssertFalse([[[TikTokBusiness getInstance] valueForKey:@"paymentTrackingEnabled"] boolValue]);
    XCTAssertNil(TTSDKCrash.sharedInstance.reportStore, @"Optional crash monitors must never be installed in consent mode");
    [self completeTask:self.session.requests[1] status:200 config:@{
        @"enable_debug_mode":@YES, @"enable_screenshot":@YES
    }];
    XCTAssertFalse([[[TikTokBusiness getInstance] valueForKey:@"screenshotEnabled"] boolValue], @"Remote debug config cannot enable screenshots without local debug opt-in");
}

- (void)testPurgeAcknowledgementIncludesLegacyCrashReports {
    TTSDKCrashReportStoreConfiguration *configuration = [TTSDKCrashReportStoreConfiguration new];
    TTSDKCrashReportStoreCConfiguration native = [configuration toCConfiguration];
    TTSDKCrashReportStore *store = [TTSDKCrashReportStore defaultStoreWithError:nil];
    const char *report = "{\"consent_test\":true}";
    XCTAssertNotEqual(ttsdkcrs_addUserReport(report, (int)strlen(report), &native), 0);
    XCTAssertGreaterThan(store.reportCount, 0);
    [self purgeAndWait];
    XCTAssertEqual(store.reportCount, 0);
    TTSDKCrashReportStoreCConfiguration_Release(&native);
}

@end
