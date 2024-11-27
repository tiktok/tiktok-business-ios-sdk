//
//  TTSDKCrashMonitor.h
//
//  Created by Karl Stenerud on 2012-02-12.
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

/** Keeps watch for crashes and informs via callback when on occurs.
 */

#ifndef HDR_TTSDKCrashMonitor_h
#define HDR_TTSDKCrashMonitor_h

#include <stdbool.h>

#include "TTSDKCrashMonitorFlag.h"
#include "TTSDKThread.h"

#ifdef __cplusplus
extern "C" {
#endif

struct TTSDKCrash_MonitorContext;

typedef struct {
    const char *(*monitorId)(void);
    TTSDKCrashMonitorFlag (*monitorFlags)(void);
    void (*setEnabled)(bool isEnabled);
    bool (*isEnabled)(void);
    void (*addContextualInfoToEvent)(struct TTSDKCrash_MonitorContext *eventContext);
    void (*notifyPostSystemEnable)(void);
} TTSDKCrashMonitorAPI;

// ============================================================================
#pragma mark - External API -
// ============================================================================

/**
 * Activates all added crash monitors.
 *
 * Enables all monitors that have been added to the system. However, not all
 * monitors may be activated due to certain conditions. Monitors that are
 * considered unsafe in a debugging environment or require specific safety
 * measures for asynchronous operations may not be activated. The function
 * checks the current environment and adjusts the activation status of each
 * monitor accordingly.
 *
 * @return bool True if at least one monitor was successfully activated, false if no monitors were activated.
 */
bool ttsdkcm_activateMonitors(void);

/**
 * Disables all active crash monitors.
 *
 * Turns off all currently active monitors.
 */
void ttsdkcm_disableAllMonitors(void);

/**
 * Adds a crash monitor to the system.
 *
 * @param api Pointer to the monitor's API.
 * @return `true` if the monitor was successfully added, `false` if it was not.
 *
 * This function attempts to add a monitor to the system. Monitors with `NULL`
 * identifiers or identical identifiers to already added monitors are not
 * added to avoid issues and duplication. Even if a monitor is successfully
 * added, it does not guarantee that the monitor will be activated. Activation
 * depends on various factors, including the environment, debugger presence,
 * and async safety requirements.
 */
bool ttsdkcm_addMonitor(TTSDKCrashMonitorAPI *api);

/**
 * Removes a crash monitor from the system.
 *
 * @param api Pointer to the monitor's API.
 *
 * If the monitor is found, it is removed from the system.
 */
void ttsdkcm_removeMonitor(const TTSDKCrashMonitorAPI *api);

/**
 * Sets the callback for event capture.
 *
 * @param onEvent Callback function for events.
 *
 * Registers a callback to be invoked when an event occurs.
 */
void ttsdkcm_setEventCallback(void (*onEvent)(struct TTSDKCrash_MonitorContext *monitorContext));

// Uncomment and implement if needed.
/**
 * Retrieves active crash monitors.
 *
 * @return Active monitors.
 */
// TTSDKCrashMonitorType ttsdkcm_getActiveMonitors(void);

// ============================================================================
#pragma mark - Internal API -
// ============================================================================

/** Notify that a fatal exception has been captured.
 *  This allows the system to take appropriate steps in preparation.
 *
 * @param isAsyncSafeEnvironment If true, only async-safe functions are allowed from now on.
 */
bool ttsdkcm_notifyFatalExceptionCaptured(bool isAsyncSafeEnvironment);

/** Start general exception processing.
 *
 * @param context Contextual information about the exception.
 */
void ttsdkcm_handleException(struct TTSDKCrash_MonitorContext *context);

#ifdef __cplusplus
}
#endif

#endif  // HDR_TTSDKCrashMonitor_h
