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
#import "TTSDKCrashMonitor_BootTime.h"
#import "TTSDKCrashMonitorContext.h"
#import "TikTokDebugInfo.h"
#import "TikTokCypher.h"
#import "TikTokEDPConfig.h"

// A deterministic transport: no test contacts TikTok and responses can arrive
// after cancellation, just as an already-running NSURLSession callback can.
@interface TTConsentTask : NSURLSessionDataTask
@property (nonatomic, strong) NSURLRequest *request;
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
    task.request = request;
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

- (NSDictionary *)payloadForTask:(TTConsentTask *)task {
    NSData *body = task.request.HTTPBody;
    if ([TikTokCypher isGzippedData:body]) {
        TikTokCypherResultErrorCode error = TikTokCypherResultNone;
        body = [TikTokCypher gzipUncompressData:body error:&error];
        XCTAssertEqual(error, TikTokCypherResultNone);
    }
    NSError *error;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:body options:0 error:&error];
    XCTAssertNil(error);
    return payload;
}

- (TikTokAppEvent *)monitorNamed:(NSString *)name {
    return [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:@{
        @"monitor_type":@"metric", @"monitor_name":name,
        @"meta":@{@"legacy_payload":@"should not leave device"}
    } withType:@"monitor"];
}

// Seed bytes exactly as an older binary did, bypassing this version's new-write gate.
- (void)seedLegacyMonitor:(TikTokAppEvent *)event {
    TikTokDatabase *db = [[TikTokMonitorEventPersistence persistence] valueForKey:@"db"];
    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:YES error:&error];
    XCTAssertNil(error);
    BOOL inserted = [db insertIntoTable:@"monitor_event_table" fields:@{
        @"event_data":data, @"ts":event.timestamp, @"retry_times":@0,
        @"sending":@0, @"is_edp_event":@0
    }];
    XCTAssertTrue(inserted);
}

- (void)testRawBootTelemetryRetiredAndLegacyHistoryPurged {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:@{@"old-boot":@123} forKey:TTBTMsDictKey];
    [defaults setObject:@{@"old-boot":@123} forKey:TTBTSDictKey];
    [self purgeAndWait];
    XCTAssertNil([defaults objectForKey:TTBTMsDictKey]);
    XCTAssertNil([defaults objectForKey:TTBTSDictKey]);
    XCTAssertEqual([TikTokDebugInfo debugInfo].count, 0);
    TTSDKCrashMonitorAPI *api = ttsdkcm_boottime_getAPI();
    api->setEnabled(true);
    XCTAssertFalse(api->isEnabled(), @"Even optional crash instrumentation cannot collect raw boot time");
    TTSDKCrash_MonitorContext context = {0};
    api->addContextualInfoToEvent(&context);
    XCTAssertTrue(context.System.bootTime == NULL);
}

- (void)testConfigurationPayloadHasNoDetailedTelemetryAndRemoteCannotChangeConsentHost {
    TikTokConfig *config = [self activeConsentConfig];
    [TikTokBusiness initializeSdk:config];
    XCTAssertEqual(self.session.requests.count, 2);
    for (TTConsentTask *task in self.session.requests) {
        NSDictionary *payload = [self payloadForTask:task];
        XCTAssertNil(payload[@"monitors"], @"Neither configuration endpoint may attach debug_info");
        XCTAssertNotNil(payload[@"app"]);
        XCTAssertNotNil(payload[@"device"]);
    }
    [self completeTask:self.session.requests.firstObject status:200 config:@{
        @"enable_sdk":@YES, @"enable_debug_info":@YES,
        @"domain":@"undeclared-tracker.invalid"
    }];
    [[TikTokFactory getRequestHandler] sendBatchRequest:@[[self seededEvent]] withConfig:config];
    [[TikTokFactory getRequestHandler] getDebugMode:config withCompletionHandler:^(NSDictionary *global, NSError *error) {}];
    for (TTConsentTask *task in self.session.requests) {
        XCTAssertEqualObjects(task.request.URL.host, @"analytics.us.tiktok.com");
    }
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);
}

- (void)testProductionDropsNewAndLegacyOptionalMonitorsWithoutStoppingAppEvents {
    TikTokAppEvent *debug = [self monitorNamed:@"debug_info"];
    TikTokAppEvent *network = [self monitorNamed:@"network_req"];
    [self seedLegacyMonitor:debug];
    [self seedLegacyMonitor:network];
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 2);
    TikTokConfig *config = [self activeConsentConfig];
    [TikTokBusiness initializeSdk:config];
    XCTAssertFalse([TikTokBusiness canCollectDiagnosticEvents]);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] retrievePersistedEvents].count, 0);
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);
    [[TikTokMonitorEventPersistence persistence] persistEvents:@[debug, network]];
    XCTAssertEqual([[TikTokMonitorEventPersistence persistence] eventsCount], 0);
    NSUInteger count = self.session.requests.count;
    [[TikTokFactory getRequestHandler] sendMonitorRequest:@[debug, network] withConfig:config];
    XCTAssertEqual(self.session.requests.count, count);
    TikTokAppEvent *subscription = [[TikTokAppEvent alloc] initWithEventName:@"Subscribe"
        withProperties:@{@"product":@"speaking_coach", @"plan":@"pro"} withType:@"track"];
    subscription.screenshot = @"legacy-screen-content";
    TikTokAppEvent *legacyEDP = [[TikTokAppEvent alloc] initWithEventName:@"page_show"
        withProperties:@{@"monitor_type":@"enhanced_data_postback", @"page_components":@"legacy-conversation"} withType:@"track"];
    XCTAssertTrue(legacyEDP.isEDPEvent);
    [[TikTokFactory getRequestHandler] sendBatchRequest:@[subscription, legacyEDP] withConfig:config];
    XCTAssertEqual(self.session.requests.count, count + 1);
    NSDictionary *payload = [self payloadForTask:self.session.requests.lastObject];
    NSArray *batch = payload[@"batch"];
    XCTAssertEqual(batch.count, 1);
    XCTAssertEqualObjects(batch.firstObject[@"event"], @"Subscribe");
    XCTAssertNil(batch.firstObject[@"screenshot"], @"Legacy screenshots must not leave a production binary");
}

- (void)testDiagnosticsRequireLocalDebugAndConsentButRetiredDebugInfoNeverReturns {
    TikTokConfig *config = [self activeConsentConfig];
    [config enableDebugMode];
    [TikTokBusiness initializeSdk:config];
    XCTAssertTrue([TikTokBusiness canCollectDiagnosticEvents]);
    TikTokAppEvent *debug = [self monitorNamed:@"debug_info"];
    [self seedLegacyMonitor:debug];
    NSArray *events = [[TikTokMonitorEventPersistence persistence] retrievePersistedEvents];
    for (TikTokAppEvent *event in events) {
        XCTAssertFalse([TikTokDebugInfo isRetiredMonitor:event.properties]);
    }
    NSUInteger count = self.session.requests.count;
    [[TikTokFactory getRequestHandler] sendMonitorRequest:@[debug] withConfig:config];
    XCTAssertEqual(self.session.requests.count, count);
    TikTokAppEvent *network = [self monitorNamed:@"network_req"];
    [[TikTokFactory getRequestHandler] sendMonitorRequest:@[network] withConfig:config];
    XCTAssertEqual(self.session.requests.count, count + 1);
    [TikTokBusiness setTrackingEnabled:NO];
    [self purgeAndWait];
    XCTAssertFalse([TikTokBusiness canCollectDiagnosticEvents]);
    [[TikTokFactory getRequestHandler] sendMonitorRequest:@[network] withConfig:config];
    XCTAssertEqual(self.session.requests.count, count + 1);
}

- (void)testRemoteEDPConfigCannotEnableLocallyDisabledCollection {
    [TikTokBusiness initializeSdk:[self activeConsentConfig]];
    [self completeTask:self.session.requests.firstObject status:200 config:@{
        @"enable_sdk":@YES,
        @"enhanced_data_postback_native_config":@{
            @"enable_sdk":@YES, @"enable_from_ttconfig":@YES,
            @"enable_app_launch_track":@YES, @"enable_page_show_track":@YES,
            @"enable_click_track":@YES, @"enable_pay_show_track":@YES
        }
    }];
    XCTAssertTrue(TikTokEDPConfig.sharedConfig.enable_sdk);
    XCTAssertFalse(TikTokEDPConfig.sharedConfig.enable_from_ttconfig);
    dispatch_sync([[TikTokBusiness getEventLogger] valueForKey:@"loggerQueue"], ^{});
    for (TikTokAppEvent *event in [[TikTokAppEventPersistence persistence] retrievePersistedEvents]) {
        XCTAssertFalse(event.isEDPEvent, @"Remote enable must not capture launch or UI contents");
    }
}

@end
