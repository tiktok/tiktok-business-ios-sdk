//
//  TTSDKCrashMonitor_Deadlock.m
//
//  Created by Karl Stenerud on 2012-12-09.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

#import "TTSDKCrashMonitor_Deadlock.h"

#import <Foundation/Foundation.h>
#import "TTSDKCrashMonitorContext.h"
#import "TTSDKCrashMonitorContextHelper.h"
#import "TTSDKID.h"
#import "TTSDKStackCursor_MachineContext.h"
#import "TTSDKThread.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

#define kIdleInterval 5.0f

@class TTSDKCrashDeadlockMonitor;

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = false;

static TTSDKCrash_MonitorContext g_monitorContext;

/** Thread which monitors other threads. */
static TTSDKCrashDeadlockMonitor *g_monitor;

static TTSDKThread g_mainQueueThread;

/** Interval between watchdog pulses. */
static NSTimeInterval g_watchdogInterval = 0;

// ============================================================================
#pragma mark - X -
// ============================================================================

@interface TTSDKCrashDeadlockMonitor : NSObject

@property(nonatomic, readwrite, strong) NSThread *monitorThread;
@property(atomic, readwrite, assign) BOOL awaitingResponse;

@end

@implementation TTSDKCrashDeadlockMonitor

- (id)init
{
    if ((self = [super init])) {
        // target (self) is retained until selector (runMonitor) exits.
        _monitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(runMonitor) object:nil];
        _monitorThread.name = @"TTSDKCrash Deadlock Detection Thread";
        [_monitorThread start];
    }
    return self;
}

- (void)cancel
{
    [self.monitorThread cancel];
}

- (void)watchdogPulse
{
    __block id blockSelf = self;
    self.awaitingResponse = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [blockSelf watchdogAnswer];
    });
}

- (void)watchdogAnswer
{
    self.awaitingResponse = NO;
}

- (void)handleDeadlock
{
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t numThreads = 0;
    ttsdkmc_suspendEnvironment(&threads, &numThreads);
    ttsdkcm_notifyFatalExceptionCaptured(false);

    TTSDKMC_NEW_CONTEXT(machineContext);
    ttsdkmc_getContextForThread(g_mainQueueThread, machineContext, false);
    TTSDKStackCursor stackCursor;
    ttsdttsdkc_initWithMachineContext(&stackCursor, TTSDKSC_MAX_STACK_DEPTH, machineContext);
    char eventID[37];
    ttsdkid_generate(eventID);

    TTSDKLOG_DEBUG(@"Filling out context.");
    TTSDKCrash_MonitorContext *crashContext = &g_monitorContext;
    memset(crashContext, 0, sizeof(*crashContext));
    ttsdkmc_fillMonitorContext(crashContext, ttsdkcm_deadlock_getAPI());
    crashContext->eventID = eventID;
    crashContext->registersAreValid = false;
    crashContext->offendingMachineContext = machineContext;
    crashContext->stackCursor = &stackCursor;

    ttsdkcm_handleException(crashContext);
    ttsdkmc_resumeEnvironment(threads, numThreads);

    TTSDKLOG_DEBUG(@"Calling abort()");
    abort();
}

- (void)runMonitor
{
    BOOL cancelled = NO;
    do {
        // Only do a watchdog check if the watchdog interval is > 0.
        // If the interval is <= 0, just idle until the user changes it.
        @autoreleasepool {
            NSTimeInterval sleepInterval = g_watchdogInterval;
            BOOL runWatchdogCheck = sleepInterval > 0;
            if (!runWatchdogCheck) {
                sleepInterval = kIdleInterval;
            }
            [NSThread sleepForTimeInterval:sleepInterval];
            cancelled = self.monitorThread.isCancelled;
            if (!cancelled && runWatchdogCheck) {
                if (self.awaitingResponse) {
                    [self handleDeadlock];
                } else {
                    [self watchdogPulse];
                }
            }
        }
    } while (!cancelled);
}

@end

// ============================================================================
#pragma mark - API -
// ============================================================================

static void initialize(void)
{
    static bool isInitialized = false;
    if (!isInitialized) {
        isInitialized = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            g_mainQueueThread = ttsdkthread_self();
        });
    }
}

static const char *monitorId(void) { return "MainThreadDeadlock"; }

static TTSDKCrashMonitorFlag monitorFlags(void) { return TTSDKCrashMonitorFlagFatal; }

static void setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            TTSDKLOG_DEBUG(@"Creating new deadlock monitor.");
            initialize();
            g_monitor = [[TTSDKCrashDeadlockMonitor alloc] init];
        } else {
            TTSDKLOG_DEBUG(@"Stopping deadlock monitor.");
            [g_monitor cancel];
            g_monitor = nil;
        }
    }
}

static bool isEnabled(void) { return g_isEnabled; }

TTSDKCrashMonitorAPI *ttsdkcm_deadlock_getAPI(void)
{
    static TTSDKCrashMonitorAPI api = {
        .monitorId = monitorId, .monitorFlags = monitorFlags, .setEnabled = setEnabled, .isEnabled = isEnabled
    };
    return &api;
}

void ttsdkcm_setDeadlockHandlerWatchdogInterval(double value) { g_watchdogInterval = value; }
