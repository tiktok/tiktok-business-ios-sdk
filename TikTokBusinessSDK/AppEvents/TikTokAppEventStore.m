//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import "TikTokAppEventStore.h"
#import "TikTokAppEventQueue.h"
#import "TikTokErrorHandler.h"

#define DISK_LIMIT 500

// Optimization to skip check if we know there are no persisted events
static BOOL canSkipDiskCheck = NO;
// Total number of events dumped as a result of exceeding max number of events in disk
static long numberOfEventsDumped = 0;

@implementation TikTokAppEventStore

+ (void)clearPersistedAppEvents
{
    [[NSFileManager defaultManager] removeItemAtPath:[[self class] getFilePath]
                                               error:NULL];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"inDiskEventQueueUpdated" object:nil];
    canSkipDiskCheck = YES;
}

+ (void)persistAppEvents:(NSArray *)queue
{
    if (!queue.count) {
        return;
    }
    @try {
        BOOL result;
        NSMutableArray *existingEvents = [NSMutableArray arrayWithArray:[[self class] retrievePersistedAppEvents]];
        [[self class] clearPersistedAppEvents];
        [existingEvents addObjectsFromArray:queue];
        
        // if number of events to store is greater than DISK_LIMIT, store the later events with length of DISK_LIMIT
        if(existingEvents.count > DISK_LIMIT) {
            long difference = existingEvents.count - DISK_LIMIT;
            numberOfEventsDumped += difference;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"eventsDumped" object:nil userInfo:@{@"numberOfEventsDumped":@(numberOfEventsDumped)}];
            NSArray *existingEventsSliced = [existingEvents subarrayWithRange:NSMakeRange(difference, DISK_LIMIT)];
            // converts back to NSMutableArray type
            existingEvents = [existingEventsSliced mutableCopy];
        }
        
        if (@available(iOS 11, *)) {
            NSError *errorArchiving = nil;
            // archivedDataWithRootObject:requiringSecureCoding: available iOS 11.0+
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:existingEvents requiringSecureCoding:NO error:&errorArchiving];
            if (data && errorArchiving == nil) {
                NSError *errorWriting = nil;
                result = [data writeToFile:[[self class] getFilePath] options:NSDataWritingAtomic error:&errorWriting];
                result = result && (errorWriting == nil);
            } else {
                result = NO;
            }
        } else {
            // archiveRootObject used for iOS versions below 11.0
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            result = [NSKeyedArchiver archiveRootObject:existingEvents toFile:[[self class] getFilePath]];
#pragma clang diagnostic pop
        }
        
        if(result == YES) {
            canSkipDiskCheck = NO;
        } else {
            [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to persist to disk"];
        }
    } @catch (NSException *exception) {
        [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to persist to disk" exception:exception];
    }
}

+ (NSArray *)retrievePersistedAppEvents
{
    NSMutableArray *events = [NSMutableArray array];
    if (!canSkipDiskCheck) {
        @try {
            if (@available(iOS 11, *)) {
                NSData *data = [NSData dataWithContentsOfFile:[[self class] getFilePath]];
                NSError *errorUnarchiving = nil;
                // initForReadingFromData:error: available iOS 11.0+
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&errorUnarchiving];
                [unarchiver setRequiresSecureCoding:NO];
                [events addObjectsFromArray:[unarchiver decodeObjectOfClass:[NSArray class] forKey:NSKeyedArchiveRootObjectKey]];
            } else {
                // unarchiveObjectWithFile used for iOS versions below 11.0
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                [events addObjectsFromArray:[NSKeyedUnarchiver unarchiveObjectWithFile:[[self class] getFilePath]]];
#pragma clang diagnostic pop
            }
        } @catch (NSException *exception) {
            [TikTokErrorHandler handleErrorWithOrigin:NSStringFromClass([self class]) message:@"Failed to read from disk" exception:exception];
            // if exception is caused and failed to read from disk, delete the file
            [[self class] clearPersistedAppEvents];
        }
    }
    
    return events;
}

#pragma mark - Private Helpers

+ (NSString *)getFilePath
{
    NSSearchPathDirectory directory = NSLibraryDirectory;
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    NSString *docDirectory = [paths objectAtIndex:0];
    return [docDirectory stringByAppendingPathComponent:@"com-tiktok-sdk-AppEventsPersistedEvents.json"];
}

@end
