//
//  TTSDKCrashMonitor.c
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

#include "TTSDKCrashMonitor.h"

#include <memory.h>
#include <stdlib.h>

#include "TTSDKCrashMonitorContext.h"
#include "TTSDKCrashMonitorHelper.h"
#include "TTSDKDebug.h"
#include "TTSDKString.h"
#include "TTSDKSystemCapabilities.h"
#include "TTSDKThread.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

typedef struct {
    TTSDKCrashMonitorAPI **apis;  // Array of MonitorAPIs
    size_t count;
    size_t capacity;
} MonitorList;

#define INITIAL_MONITOR_CAPACITY 15

#pragma mark - Helpers

__attribute__((unused))  // Suppress unused function warnings, especially in release builds.
static inline const char *
getMonitorNameForLogging(const TTSDKCrashMonitorAPI *api)
{
    return ttsdkcm_getMonitorId(api) ?: "Unknown";
}

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static MonitorList g_monitors = {};

static bool g_areMonitorsInitialized = false;
static bool g_handlingFatalException = false;
static bool g_crashedDuringExceptionHandling = false;
static bool g_requiresAsyncSafety = false;

static void (*g_onExceptionEvent)(struct TTSDKCrash_MonitorContext *monitorContext);

static void initializeMonitorList(MonitorList *list)
{
    list->count = 0;
    list->capacity = INITIAL_MONITOR_CAPACITY;
    list->apis = (TTSDKCrashMonitorAPI **)malloc(list->capacity * sizeof(TTSDKCrashMonitorAPI *));
}

static void addMonitor(MonitorList *list, TTSDKCrashMonitorAPI *api)
{
    if (list->count >= list->capacity) {
        list->capacity *= 2;
        list->apis = (TTSDKCrashMonitorAPI **)realloc(list->apis, list->capacity * sizeof(TTSDKCrashMonitorAPI *));
    }
    list->apis[list->count++] = api;
}

static void removeMonitor(MonitorList *list, const TTSDKCrashMonitorAPI *api)
{
    if (list == NULL || api == NULL) {
        TTSDKLOG_DEBUG("Either list or func is NULL. Removal operation aborted.");
        return;
    }

    bool found = false;

    for (size_t i = 0; i < list->count; i++) {
        if (list->apis[i] == api) {
            found = true;

            ttsdkcm_setMonitorEnabled(list->apis[i], false);

            // Replace the current monitor with the last monitor in the list
            list->apis[i] = list->apis[list->count - 1];
            list->count--;
            list->apis[list->count] = NULL;

            TTSDKLOG_DEBUG("Monitor %s removed from the list.", getMonitorNameForLogging(api));
            break;
        }
    }

    if (!found) {
        TTSDKLOG_DEBUG("Monitor %s not found in the list. No removal performed.", getMonitorNameForLogging(api));
    }
}

static void freeMonitorFuncList(MonitorList *list)
{
    free(list->apis);
    list->apis = NULL;
    list->count = 0;
    list->capacity = 0;

    g_areMonitorsInitialized = false;
}

__attribute__((unused)) // For tests. Declared as extern in TestCase
void ttsdkcm_resetState(void)
{
    freeMonitorFuncList(&g_monitors);
    g_handlingFatalException = false;
    g_crashedDuringExceptionHandling = false;
    g_requiresAsyncSafety = false;
    g_onExceptionEvent = NULL;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

void ttsdkcm_setEventCallback(void (*onEvent)(struct TTSDKCrash_MonitorContext *monitorContext))
{
    g_onExceptionEvent = onEvent;
}

bool ttsdkcm_activateMonitors(void)
{
    // Check for debugger and async safety
    bool isDebuggerUnsafe = ttsdkdebug_isBeingTraced();
    bool isAsyncSafeRequired = g_requiresAsyncSafety;

    if (isDebuggerUnsafe) {
        static bool hasWarned = false;
        if (!hasWarned) {
            hasWarned = true;
            TTSDKLOGBASIC_WARN("    ************************ Crash Handler Notice ************************");
            TTSDKLOGBASIC_WARN("    *     App is running in a debugger. Masking out unsafe monitors.     *");
            TTSDKLOGBASIC_WARN("    * This means that most crashes WILL NOT BE RECORDED while debugging! *");
            TTSDKLOGBASIC_WARN("    **********************************************************************");
        }
    }

    if (isAsyncSafeRequired) {
        TTSDKLOG_DEBUG("Async-safe environment detected. Masking out unsafe monitors.");
    }

    // Enable or disable monitors
    for (size_t i = 0; i < g_monitors.count; i++) {
        TTSDKCrashMonitorAPI *api = g_monitors.apis[i];
        TTSDKCrashMonitorFlag flags = ttsdkcm_getMonitorFlags(api);
        bool shouldEnable = true;

        if (isDebuggerUnsafe && (flags & TTSDKCrashMonitorFlagDebuggerUnsafe)) {
            shouldEnable = false;
        }

        if (isAsyncSafeRequired && !(flags & TTSDKCrashMonitorFlagAsyncSafe)) {
            shouldEnable = false;
        }

        ttsdkcm_setMonitorEnabled(api, shouldEnable);
    }

    bool anyMonitorActive = false;

    // Log active monitors
    TTSDKLOG_DEBUG("Active monitors are now:");
    for (size_t i = 0; i < g_monitors.count; i++) {
        TTSDKCrashMonitorAPI *api = g_monitors.apis[i];
        if (ttsdkcm_isMonitorEnabled(api)) {
            TTSDKLOG_DEBUG("Monitor %s is enabled.", getMonitorNameForLogging(api));
            anyMonitorActive = true;
        } else {
            TTSDKLOG_DEBUG("Monitor %s is disabled.", getMonitorNameForLogging(api));
        }
    }

    // Notify monitors about system enable
    for (size_t i = 0; i < g_monitors.count; i++) {
        TTSDKCrashMonitorAPI *api = g_monitors.apis[i];
        ttsdkcm_notifyPostSystemEnable(api);
    }

    return anyMonitorActive;
}

void ttsdkcm_disableAllMonitors(void)
{
    for (size_t i = 0; i < g_monitors.count; i++) {
        TTSDKCrashMonitorAPI *api = g_monitors.apis[i];
        ttsdkcm_setMonitorEnabled(api, false);
    }
    TTSDKLOG_DEBUG("All monitors have been disabled.");
}

bool ttsdkcm_addMonitor(TTSDKCrashMonitorAPI *api)
{
    if (api == NULL) {
        TTSDKLOG_DEBUG("Attempted to add a NULL monitor. Operation aborted.");
        return false;
    }

    const char *newMonitorId = ttsdkcm_getMonitorId(api);
    if (newMonitorId == NULL) {
        TTSDKLOG_DEBUG("Monitor has a NULL ID. Operation aborted.");
        return false;
    }

    if (!g_areMonitorsInitialized) {
        initializeMonitorList(&g_monitors);
        g_areMonitorsInitialized = true;
    }

    // Check for duplicate monitors
    for (size_t i = 0; i < g_monitors.count; i++) {
        TTSDKCrashMonitorAPI *existingApi = g_monitors.apis[i];
        const char *existingMonitorId = ttsdkcm_getMonitorId(existingApi);

        if (ttsdkstring_safeStrcmp(existingMonitorId, newMonitorId) == 0) {
            TTSDKLOG_DEBUG("Monitor %s already exists. Skipping addition.", getMonitorNameForLogging(api));
            return false;
        }
    }

    addMonitor(&g_monitors, api);
    TTSDKLOG_DEBUG("Monitor %s injected.", getMonitorNameForLogging(api));
    return true;
}

void ttsdkcm_removeMonitor(const TTSDKCrashMonitorAPI *api)
{
    if (api == NULL) {
        TTSDKLOG_DEBUG("Attempted to remove a NULL monitor. Operation aborted.");
        return;
    }

    removeMonitor(&g_monitors, api);
}

// TTSDKCrashMonitorType ttsdkcm_getActiveMonitors(void)
//{
//     return g_monitors;
// }

// ============================================================================
#pragma mark - Private API -
// ============================================================================

bool ttsdkcm_notifyFatalExceptionCaptured(bool isAsyncSafeEnvironment)
{
    g_requiresAsyncSafety |= isAsyncSafeEnvironment;  // Don't let it be unset.
    if (g_handlingFatalException) {
        g_crashedDuringExceptionHandling = true;
    }
    g_handlingFatalException = true;
    if (g_crashedDuringExceptionHandling) {
        TTSDKLOG_INFO("Detected crash in the crash reporter. Uninstalling TTSDKCrash.");
        ttsdkcm_disableAllMonitors();
    }
    return g_crashedDuringExceptionHandling;
}

void ttsdkcm_handleException(struct TTSDKCrash_MonitorContext *context)
{
    // We're handling a crash if the crash type is fatal
    bool hasFatalFlag = (context->monitorFlags & TTSDKCrashMonitorFlagFatal) != TTSDKCrashMonitorFlagNone;
    context->handlingCrash = context->handlingCrash || hasFatalFlag;

    context->requiresAsyncSafety = g_requiresAsyncSafety;
    if (g_crashedDuringExceptionHandling) {
        context->crashedDuringCrashHandling = true;
    }

    // Add contextual info to the event for all enabled monitors
    for (size_t i = 0; i < g_monitors.count; i++) {
        TTSDKCrashMonitorAPI *api = g_monitors.apis[i];
        if (ttsdkcm_isMonitorEnabled(api)) {
            ttsdkcm_addContextualInfoToEvent(api, context);
        }
    }

    // Call the exception event handler if it exists
    if (g_onExceptionEvent) {
        g_onExceptionEvent(context);
    }

    // Restore original handlers if the exception is fatal and not already handled
    if (context->currentSnapshotUserReported) {
        g_handlingFatalException = false;
    } else {
        if (g_handlingFatalException && !g_crashedDuringExceptionHandling) {
            TTSDKLOG_DEBUG("Exception is fatal. Restoring original handlers.");
            ttsdkcm_disableAllMonitors();
        }
    }

    // Done handling the crash
    context->handlingCrash = false;
}
