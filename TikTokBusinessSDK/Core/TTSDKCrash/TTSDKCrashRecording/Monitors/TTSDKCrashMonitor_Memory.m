//
//  TTSDKCrashMonitor_Memory.h
//
//  Created by Alexander Cohen on 2024-05-20.
//
//  Copyright (c) 2024 Alexander Cohen. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
#import "TTSDKCrashMonitor_Memory.h"

#import "TTSDKCrash.h"
#import "TTSDKCrashAppMemory.h"
#import "TTSDKCrashAppMemoryTracker.h"
#import "TTSDKCrashAppStateTracker.h"
#import "TTSDKCrashC.h"
#import "TTSDKCrashMonitorContext.h"
#import "TTSDKCrashMonitorContextHelper.h"
#import "TTSDKCrashReportFields.h"
#import "TTSDKCrashReportStoreC.h"
#import "TTSDKDate.h"
#import "TTSDKFileUtils.h"
#import "TTSDKID.h"
#import "TTSDKStackCursor.h"
#import "TTSDKStackCursor_MachineContext.h"
#import "TTSDKStackCursor_SelfThread.h"
#import "TTSDKSystemCapabilities.h"

#import <Foundation/Foundation.h>
#import <os/lock.h>

#import "TTSDKLogger.h"

#if TTSDKCRASH_HAS_UIAPPLICATION
#import <UIKit/UIKit.h>
#endif

const int32_t TTSDKCrash_Memory_Magic = 'ttcm';

const uint8_t TTSDKCrash_Memory_Version_1 = 1;
const uint8_t TTSDKCrash_Memory_CurrentVersion = TTSDKCrash_Memory_Version_1;

const uint8_t TTSDKCrash_Memory_NonFatalReportLevelNone = TTSDKCrashAppMemoryStateTerminal + 1;

// ============================================================================
#pragma mark - Forward declarations -
// ============================================================================

static TTSDKCrash_Memory _ttsdk_memory_copy(void);
static void _ttsdk_memory_update(void (^block)(TTSDKCrash_Memory *mem));
static void _ttsdk_memory_update_from_app_memory(TTSDKCrashAppMemory *const memory);
static void ttsdkmemory_write_possible_oom(void);
static void setEnabled(bool isEnabled);
static bool isEnabled(void);
static NSURL *ttsdkcm_memory_oom_breadcrumb_URL(void);
static void addContextualInfoToEvent(TTSDKCrash_MonitorContext *eventContext);
static NSDictionary<NSString *, id> *ttsdkcm_memory_serialize(TTSDKCrash_Memory *const memory);
static void ttsdkcm_memory_check_for_oom_in_previous_session(void);
static void notifyPostSystemEnable(void);
static void ttsdkmemory_read(const char *path);
static void ttsdkmemory_map(const char *path);

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = 0;
static volatile bool g_hasPostEnable = 0;

// What we're reporting
static uint8_t g_MinimumNonFatalReportingLevel = TTSDKCrash_Memory_NonFatalReportLevelNone;
static bool g_FatalReportsEnabled = true;

// Install path for the crash system
static NSURL *g_dataURL = nil;
static NSURL *g_memoryURL = nil;

// The memory tracker
@class _TTSDKCrashMonitor_MemoryTracker;
static _TTSDKCrashMonitor_MemoryTracker *g_memoryTracker = nil;

// Observer token for app state transitions.
static id<TTSDKCrashAppStateTrackerObserving> g_appStateObserver = nil;

// file mapped memory.
// Never touch `g_memory` directly,
// always call `_ttsdk_memory_update`.
// ex:
// _ttsdk_memory_update(^(TTSDKCrash_Memory *mem){
//      mem->x = ...
//  });
static os_unfair_lock g_memoryLock = OS_UNFAIR_LOCK_INIT;
static TTSDKCrash_Memory *g_memory = NULL;

static TTSDKCrash_Memory _ttsdk_memory_copy(void)
{
    TTSDKCrash_Memory copy = { 0 };
    {
        os_unfair_lock_lock(&g_memoryLock);
        if (g_memory) {
            copy = *g_memory;
        }
        os_unfair_lock_unlock(&g_memoryLock);
    }
    return copy;
}

static void _ttsdk_memory_update(void (^block)(TTSDKCrash_Memory *mem))
{
    if (!block) {
        return;
    }
    os_unfair_lock_lock(&g_memoryLock);
    if (g_memory) {
        block(g_memory);
    }
    os_unfair_lock_unlock(&g_memoryLock);
}

static void _ttsdk_memory_update_from_app_memory(TTSDKCrashAppMemory *const memory)
{
    _ttsdk_memory_update(^(TTSDKCrash_Memory *mem) {
        *mem = (TTSDKCrash_Memory) {
            .magic = TTSDKCrash_Memory_Magic,
            .version = TTSDKCrash_Memory_CurrentVersion,
            .footprint = memory.footprint,
            .remaining = memory.remaining,
            .limit = memory.limit,
            .pressure = (uint8_t)memory.pressure,
            .level = (uint8_t)memory.level,
            .timestamp = ttsdkdate_microseconds(),
            .state = TTSDKCrashAppStateTracker.sharedInstance.transitionState,
        };
    });
}

// last memory write from the previous session
static TTSDKCrash_Memory g_previousSessionMemory;

// ============================================================================
#pragma mark - Tracking -
// ============================================================================

@interface _TTSDKCrashMonitor_MemoryTracker : NSObject <TTSDKCrashAppMemoryTrackerDelegate> {
    TTSDKCrashAppMemoryTracker *_tracker;
}
@end

@implementation _TTSDKCrashMonitor_MemoryTracker

- (instancetype)init
{
    if (self = [super init]) {
        _tracker = [[TTSDKCrashAppMemoryTracker alloc] init];
        _tracker.delegate = self;
        [_tracker start];
    }
    return self;
}

- (void)dealloc
{
    [_tracker stop];
}

- (TTSDKCrashAppMemory *)memory
{
    return _tracker.currentAppMemory;
}

- (void)_updateMappedMemoryFrom:(TTSDKCrashAppMemory *)memory
{
    _ttsdk_memory_update_from_app_memory(memory);
}

- (void)appMemoryTracker:(TTSDKCrashAppMemoryTracker *)tracker
                  memory:(TTSDKCrashAppMemory *)memory
                 changed:(TTSDKCrashAppMemoryTrackerChangeType)changes
{
    if (changes & TTSDKCrashAppMemoryTrackerChangeTypeFootprint) {
        [self _updateMappedMemoryFrom:memory];
    }

    if ((changes & TTSDKCrashAppMemoryTrackerChangeTypeLevel) && memory.level >= g_MinimumNonFatalReportingLevel) {
        NSString *level = @(TTSDKCrashAppMemoryStateToString(memory.level)).uppercaseString;
        NSString *reason = [NSString stringWithFormat:@"Memory Level Is %@", level];

        [[TTSDKCrash sharedInstance] reportUserException:@"Memory Level"
                                               reason:reason
                                             language:@""
                                           lineOfCode:@"0"
                                           stackTrace:@[ @"__MEMORY_LEVEL__NON_FATAL__" ]
                                        logAllThreads:NO
                                     terminateProgram:NO];
    }

    if ((changes & TTSDKCrashAppMemoryTrackerChangeTypePressure) && memory.pressure >= g_MinimumNonFatalReportingLevel) {
        NSString *pressure = @(TTSDKCrashAppMemoryStateToString(memory.pressure)).uppercaseString;
        NSString *reason = [NSString stringWithFormat:@"Memory Pressure Is %@", pressure];

        [[TTSDKCrash sharedInstance] reportUserException:@"Memory Pressure"
                                               reason:reason
                                             language:@""
                                           lineOfCode:@"0"
                                           stackTrace:@[ @"__MEMORY_PRESSURE__NON_FATAL__" ]
                                        logAllThreads:NO
                                     terminateProgram:NO];
    }
}

@end

// ============================================================================
#pragma mark - API -
// ============================================================================

static const char *monitorId(void) { return "MemoryTermination"; }

static void setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            g_memoryTracker = [[_TTSDKCrashMonitor_MemoryTracker alloc] init];

            ttsdkmemory_map(g_memoryURL.path.UTF8String);

            g_appStateObserver = [TTSDKCrashAppStateTracker.sharedInstance
                addObserverWithBlock:^(TTSDKCrashAppTransitionState transitionState) {
                    _ttsdk_memory_update(^(TTSDKCrash_Memory *mem) {
                        mem->state = transitionState;
                    });
                }];

        } else {
            g_memoryTracker = nil;
            [TTSDKCrashAppStateTracker.sharedInstance removeObserver:g_appStateObserver];
            g_appStateObserver = nil;
        }
    }
}

static bool isEnabled(void) { return g_isEnabled; }

static NSURL *ttsdkcm_memory_oom_breadcrumb_URL(void)
{
    return [g_dataURL URLByAppendingPathComponent:@"oom_breadcrumb_report.json"];
}

static void addContextualInfoToEvent(TTSDKCrash_MonitorContext *eventContext)
{
    bool asyncSafeOnly = eventContext->requiresAsyncSafety;

    // we'll use this when reading this back on the next run
    // to know if an OOM is even possible.
    if (asyncSafeOnly) {
        g_memory->fatal = eventContext->handlingCrash;
    } else {
        _ttsdk_memory_update(^(TTSDKCrash_Memory *mem) {
            mem->fatal = eventContext->handlingCrash;
        });
    }

    if (g_isEnabled) {
        TTSDKCrash_Memory memCopy = asyncSafeOnly ? *g_memory : _ttsdk_memory_copy();
        eventContext->AppMemory.footprint = memCopy.footprint;
        eventContext->AppMemory.pressure = TTSDKCrashAppMemoryStateToString((TTSDKCrashAppMemoryState)memCopy.pressure);
        eventContext->AppMemory.remaining = memCopy.remaining;
        eventContext->AppMemory.limit = memCopy.limit;
        eventContext->AppMemory.level = TTSDKCrashAppMemoryStateToString((TTSDKCrashAppMemoryState)memCopy.level);
        eventContext->AppMemory.timestamp = memCopy.timestamp;
        eventContext->AppMemory.state = ttsdkapp_transitionStateToString(memCopy.state);
    }
}

static NSDictionary<NSString *, id> *ttsdkcm_memory_serialize(TTSDKCrash_Memory *const memory)
{
    return @{
        TTSDKCrashField_MemoryFootprint : @(memory->footprint),
        TTSDKCrashField_MemoryRemaining : @(memory->remaining),
        TTSDKCrashField_MemoryLimit : @(memory->limit),
        TTSDKCrashField_MemoryPressure : @(TTSDKCrashAppMemoryStateToString((TTSDKCrashAppMemoryState)memory->pressure)),
        TTSDKCrashField_MemoryLevel : @(TTSDKCrashAppMemoryStateToString((TTSDKCrashAppMemoryState)memory->level)),
        TTSDKCrashField_Timestamp : @(memory->timestamp),
        TTSDKCrashField_AppTransitionState : @(ttsdkapp_transitionStateToString(memory->state)),
    };
}

/**
 Check to see if the previous run was an OOM
 if it was, we load up the report created in the previous
 session and modify it, save it out to the reports location,
 and let the system run its course.
 */
static void ttsdkcm_memory_check_for_oom_in_previous_session(void)
{
    // An OOM should be the last thng we check for. For example,
    // If memory is critical but before being jetisoned we encounter
    // a programming error and receiving a Mach event or signal that
    // indicates a crash, we should process that on startup and ignore
    // and indication of an OOM.
    bool userPerceivedOOM = NO;
    if (g_FatalReportsEnabled && ttsdkmemory_previous_session_was_terminated_due_to_memory(&userPerceivedOOM)) {
        // We only report an OOM that the user might have seen.
        // Ignore this check if we want to report all OOM, foreground and background.
        if (userPerceivedOOM) {
            NSURL *url = ttsdkcm_memory_oom_breadcrumb_URL();
            const char *reportContents = ttsdkcrs_readReportAtPath(url.path.UTF8String);
            if (reportContents) {
                NSData *data = [NSData dataWithBytes:reportContents length:strlen(reportContents)];
                NSMutableDictionary *json =
                    [[NSJSONSerialization JSONObjectWithData:data
                                                     options:NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves
                                                       error:nil] mutableCopy];

                if (json) {
                    json[TTSDKCrashField_System][TTSDKCrashField_AppMemory] = ttsdkcm_memory_serialize(&g_previousSessionMemory);
                    json[TTSDKCrashField_Report][TTSDKCrashField_Timestamp] = @(g_previousSessionMemory.timestamp);
                    json[TTSDKCrashField_Crash][TTSDKCrashField_Error][TTSDKCrashExcType_MemoryTermination] =
                        ttsdkcm_memory_serialize(&g_previousSessionMemory);
                    json[TTSDKCrashField_Crash][TTSDKCrashField_Error][TTSDKCrashExcType_Mach] = nil;
                    json[TTSDKCrashField_Crash][TTSDKCrashField_Error][TTSDKCrashExcType_Signal] = @{
                        TTSDKCrashField_Signal : @(SIGKILL),
                        TTSDKCrashField_Name : @"SIGKILL",
                    };

                    data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:nil];
                    ttsdkcrash_addUserReport((const char *)data.bytes, (int)data.length);
                }
                free((void *)reportContents);
            }
        }
    }

    // remove the old breadcrumb oom file
    unlink(ttsdkcm_memory_oom_breadcrumb_URL().path.UTF8String);
}

/**
 This is called after all monitors are enabled.
 */
static void notifyPostSystemEnable(void)
{
    if (g_hasPostEnable) {
        return;
    }
    g_hasPostEnable = 1;

    // Usually we'd do something like this `setEnabled`,
    // but in this case not all monitors are ready in `seEnabled`
    // so we simply do it after everything is enabled.

    ttsdkcm_memory_check_for_oom_in_previous_session();

    if (g_isEnabled) {
        ttsdkmemory_write_possible_oom();
    }
}

TTSDKCrashMonitorAPI *ttsdkcm_memory_getAPI(void)
{
    static TTSDKCrashMonitorAPI api = {
        .monitorId = monitorId,
        .setEnabled = setEnabled,
        .isEnabled = isEnabled,
        .addContextualInfoToEvent = addContextualInfoToEvent,
        .notifyPostSystemEnable = notifyPostSystemEnable,
    };
    return &api;
}

/**
 Read the previous sessions memory data,
 and unlinks the file to remove any trace of it.
 */
static void ttsdkmemory_read(const char *path)
{
    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        unlink(path);
        return;
    }

    size_t size = sizeof(TTSDKCrash_Memory);
    TTSDKCrash_Memory memory = {};

    // This will fail is we don't receive exactly _size_.
    // In the future, we need to read and allow getting back something
    // that is not exactly _size_, then check the version to see
    // what we can or cannot use in the structure.
    if (!ttsdkfu_readBytesFromFD(fd, (char *)&memory, (int)size)) {
        close(fd);
        unlink(path);
        return;
    }

    // get rid of the file, we don't want it anymore.
    close(fd);
    unlink(path);

    // validate some of the data before doing anything with it.

    // check magic
    if (memory.magic != TTSDKCrash_Memory_Magic) {
        return;
    }

    // check version
    if (memory.version == 0 || memory.version > TTSDKCrash_Memory_CurrentVersion) {
        return;
    }

    // ---
    // START TTSDKCrash_Memory_Version_1_0
    // ---

    // check the timestamp, let's say it's valid for the last week
    // do we really want crash reports older than a week anyway??
    const uint64_t kUS_in_day = 8.64e+10;
    const uint64_t kUS_in_week = kUS_in_day * 7;
    uint64_t now = ttsdkdate_microseconds();
    if (memory.timestamp <= 0 || memory.timestamp == INT64_MAX || memory.timestamp < now - kUS_in_week) {
        return;
    }

    // check pressure and level are in ranges
    if (memory.level > TTSDKCrashAppMemoryStateTerminal) {
        return;
    }
    if (memory.pressure > TTSDKCrashAppMemoryStateTerminal) {
        return;
    }

    // check app transition state
    if (memory.state > TTSDKCrashAppTransitionStateExiting) {
        return;
    }

    // if we're at max, we likely overflowed or set a negative value,
    // in any case, we're counting this as a possible error and bailing.
    if (memory.footprint == UINT64_MAX) {
        return;
    }
    if (memory.remaining == UINT64_MAX) {
        return;
    }
    if (memory.limit == UINT64_MAX) {
        return;
    }

    // Footprint and remaining should always = limit
    if (memory.footprint + memory.remaining != memory.limit) {
        return;
    }

    // ---
    // END TTSDKCrash_Memory_Version_1_0
    // ---

    g_previousSessionMemory = memory;
}

/**
 Mapping memory to a file on disk. This allows us to simply treat the location
 in memory as a structure and the kernel will ensure it is on disk. This is also
 crash resistant.
 */
static void ttsdkmemory_map(const char *path)
{
    void *ptr = ttsdkfu_mmap(path, sizeof(TTSDKCrash_Memory));
    if (!ptr) {
        return;
    }

    g_memory = (TTSDKCrash_Memory *)ptr;
    _ttsdk_memory_update_from_app_memory(g_memoryTracker.memory);
}

/**
 What we're doing here is writing a file out that can be reused
 on restart if the data shows us there was a memory issue.

 If an OOM did happen, we'll modify this file
 (see `ttsdkcm_memory_check_for_oom_in_previous_session`),
 then write it back out using the normal writing procedure to write reports. This
 leads to the system seeing the report as if it had always been there and will
 then report an OOM.
 */
static void ttsdkmemory_write_possible_oom(void)
{
    NSURL *reportURL = ttsdkcm_memory_oom_breadcrumb_URL();
    const char *reportPath = reportURL.path.UTF8String;

    TTSDKMC_NEW_CONTEXT(machineContext);
    ttsdkmc_getContextForThread(ttsdkthread_self(), machineContext, false);
    TTSDKStackCursor stackCursor;
    ttsdttsdkc_initWithMachineContext(&stackCursor, TTSDKSC_MAX_STACK_DEPTH, machineContext);

    char eventID[37] = { 0 };
    ttsdkid_generate(eventID);

    TTSDKCrash_MonitorContext context;
    memset(&context, 0, sizeof(context));
    ttsdkmc_fillMonitorContext(&context, ttsdkcm_memory_getAPI());
    context.eventID = eventID;
    context.registersAreValid = false;
    context.offendingMachineContext = machineContext;
    context.currentSnapshotUserReported = true;

    // we don't need all the images, we have no stack
    context.omitBinaryImages = true;

    // _reportPath_ only valid within this scope
    context.reportPath = reportPath;

    ttsdkcm_handleException(&context);
}

void ttsdkmemory_initialize(const char *dataPath)
{
    g_hasPostEnable = 0;
    g_dataURL = [NSURL fileURLWithPath:@(dataPath)];
    g_memoryURL = [g_dataURL URLByAppendingPathComponent:@"memory.bin"];

    // load up the old memory data
    ttsdkmemory_read(g_memoryURL.path.UTF8String);
}

bool ttsdkmemory_previous_session_was_terminated_due_to_memory(bool *userPerceptible)
{
    // If we had any kind of fatal, even if the data says an OOM, it wasn't an OOM.
    // The idea is that we could have been very close to an OOM then some
    // exception/event occured that terminated/crashed the app. We don't want to report
    // that as an OOM.
    if (g_previousSessionMemory.fatal) {
        return NO;
    }

    // We might care if the user might have seen the OOM
    if (userPerceptible) {
        *userPerceptible = ttsdkapp_transitionStateIsUserPerceptible(g_previousSessionMemory.state);
    }

    // level or pressure is critical++
    return g_previousSessionMemory.level >= TTSDKCrashAppMemoryStateCritical ||
           g_previousSessionMemory.pressure >= TTSDKCrashAppMemoryStateCritical;
}

void ttsdkmemory_set_nonfatal_report_level(uint8_t level) { g_MinimumNonFatalReportingLevel = level; }

uint8_t ttsdkmemory_get_nonfatal_report_level(void) { return g_MinimumNonFatalReportingLevel; }

void ttsdkmemory_set_fatal_reports_enabled(bool enabled) { g_FatalReportsEnabled = enabled; }

bool ttsdkmemory_get_fatal_reports_enabled(void) { return g_FatalReportsEnabled; }

void ttsdkmemory_notifyUnhandledFatalSignal(void) { g_memory->fatal = true; }
