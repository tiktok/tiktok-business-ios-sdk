//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <XCTest/XCTest.h>
#import "TikTokAppEvent.h"
#import "TikTokAppEventStore.h"

@interface TikTokAppEventStoreTests : XCTestCase

@end

@implementation TikTokAppEventStoreTests

- (void)setUp {
    [super setUp];
    [TikTokAppEventStore clearPersistedAppEvents];
}

- (void)tearDown {
    [super tearDown];
}

+ (NSString *)getFilePath {
    NSSearchPathDirectory directory = NSLibraryDirectory;
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    NSString *docDirectory = [paths objectAtIndex:0];
    return [docDirectory stringByAppendingPathComponent:@"com-tiktok-sdk-AppEventsPersistedEvents.json"];
}

// own utility test function to retrieve items from disk to get count without clearing items immediately
+ (NSArray *)retrievePersistedAppEvents {
    NSMutableArray *retrievedEvents = [NSMutableArray array];
    
    NSData *data = [NSData dataWithContentsOfFile:[[self class] getFilePath]];
    NSError *errorUnarchiving = nil;
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&errorUnarchiving];
    [unarchiver setRequiresSecureCoding:NO];
    [retrievedEvents addObjectsFromArray:[unarchiver decodeObjectOfClass:[NSArray class] forKey:NSKeyedArchiveRootObjectKey]];
    
    return retrievedEvents;
}

- (void)testPersistAppEventsFunction {
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:@"LaunchAPP"];
    
    NSArray *events = [NSArray array];
    events = [events arrayByAddingObject:event];
    events = [events arrayByAddingObject:event];
    
    [TikTokAppEventStore persistAppEvents:events];
    
    NSMutableArray *retrievedEvents = [NSMutableArray arrayWithArray:[[self class] retrievePersistedAppEvents]];
    
    XCTAssertTrue(retrievedEvents.count == 2, @"Number of events retrieved should be 2");
    
    NSArray *additionalEvents = [NSArray array];
    additionalEvents = [additionalEvents arrayByAddingObject:event];
    additionalEvents = [additionalEvents arrayByAddingObject:event];
    additionalEvents = [additionalEvents arrayByAddingObject:event];
    
    [TikTokAppEventStore persistAppEvents:additionalEvents];
    
    NSMutableArray *retrievedEventsAfterSecondPersist = [NSMutableArray arrayWithArray:[[self class] retrievePersistedAppEvents]];
    
    XCTAssertTrue(retrievedEventsAfterSecondPersist.count == 5, @"Number of events retrieved should be 4");
}

- (void)testRetrieveAppEventsFunction {
    TikTokAppEvent *event = [[TikTokAppEvent alloc] initWithEventName:@"LaunchAPP"];
    
    NSArray *events = [NSArray array];
    events = [events arrayByAddingObject:event];
    events = [events arrayByAddingObject:event];
    
    // need to call persistAppEvents from actual class so that canSkipDiskCheck is correctly allocated to NO
    [TikTokAppEventStore persistAppEvents:events];
        
    NSMutableArray *retrievedEvents = [NSMutableArray arrayWithArray:[TikTokAppEventStore retrievePersistedAppEvents]];
    
    NSLog(@"Events count: %lu", retrievedEvents.count);
    XCTAssertTrue(retrievedEvents.count == 2, @"Number of events retrieved should be 2");
}

@end
