//
//  TTSDKCrashMonitor_AppState.c
//
//  Created by Karl Stenerud on 2012-02-05.
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

#include "TTSDKCrashMonitor_AppState.h"

#include "TTSDKCrashMonitorContext.h"
#include "TTSDKFileUtils.h"
#include "TTSDKJSONCodec.h"

// #define TTSDKLogger_LocalLevel TRACE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include "TTSDKLogger.h"

// ============================================================================
#pragma mark - Constants -
// ============================================================================

#define kFormatVersion 1

#define kKeyFormatVersion "version"
#define kKeyCrashedLastLaunch "crashedLastLaunch"
#define kKeyActiveDurationSinceLastCrash "activeDurationSinceLastCrash"
#define kKeyBackgroundDurationSinceLastCrash "backgroundDurationSinceLastCrash"
#define kKeyLaunchesSinceLastCrash "launchesSinceLastCrash"
#define kKeySessionsSinceLastCrash "sessionsSinceLastCrash"
#define kKeySessionsSinceLaunch "sessionsSinceLaunch"

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** Location where stat file is stored. */
static const char *g_stateFilePath;

/** Current state. */
static TTSDKCrash_AppState g_state;

static volatile bool g_isEnabled = false;

// ============================================================================
#pragma mark - JSON Encoding -
// ============================================================================

static int onBooleanElement(const char *const name, const bool value, void *const userData)
{
    TTSDKCrash_AppState *state = userData;

    if (strcmp(name, kKeyCrashedLastLaunch) == 0) {
        state->crashedLastLaunch = value;
    }

    return TTSDKJSON_OK;
}

static int onFloatingPointElement(const char *const name, const double value, void *const userData)
{
    TTSDKCrash_AppState *state = userData;

    if (strcmp(name, kKeyActiveDurationSinceLastCrash) == 0) {
        state->activeDurationSinceLastCrash = value;
    }
    if (strcmp(name, kKeyBackgroundDurationSinceLastCrash) == 0) {
        state->backgroundDurationSinceLastCrash = value;
    }

    return TTSDKJSON_OK;
}

static int onIntegerElement(const char *const name, const int64_t value, void *const userData)
{
    TTSDKCrash_AppState *state = userData;

    if (strcmp(name, kKeyFormatVersion) == 0) {
        if (value != kFormatVersion) {
            TTSDKLOG_ERROR("Expected version 1 but got %" PRId64, value);
            return TTSDKJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, kKeyLaunchesSinceLastCrash) == 0) {
        state->launchesSinceLastCrash = (int)value;
    } else if (strcmp(name, kKeySessionsSinceLastCrash) == 0) {
        state->sessionsSinceLastCrash = (int)value;
    }

    // FP value might have been written as a whole number.
    return onFloatingPointElement(name, value, userData);
}

static int onUnsignedIntegerElement(const char *const name, const uint64_t value, void *const userData)
{
    TTSDKCrash_AppState *state = userData;

    if (strcmp(name, kKeyFormatVersion) == 0) {
        if (value != kFormatVersion) {
            TTSDKLOG_ERROR("Expected version 1 but got %" PRIu64, value);
            return TTSDKJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, kKeyLaunchesSinceLastCrash) == 0) {
        if (value <= INT_MAX) {
            state->launchesSinceLastCrash = (int)value;
        } else {
            TTSDKLOG_ERROR("launchesSinceLastCrash (%" PRIu64 ") exceeds INT_MAX", value);
            return TTSDKJSON_ERROR_INVALID_DATA;
        }
    } else if (strcmp(name, kKeySessionsSinceLastCrash) == 0) {
        if (value <= INT_MAX) {
            state->sessionsSinceLastCrash = (int)value;
        } else {
            TTSDKLOG_ERROR("sessionsSinceLastCrash (%" PRIu64 ") exceeds INT_MAX", value);
            return TTSDKJSON_ERROR_INVALID_DATA;
        }
    }

    // For other fields or if the value doesn't fit in an int, treat it as a floating point
    return onFloatingPointElement(name, (double)value, userData);
}

static int onNullElement(__unused const char *const name, __unused void *const userData) { return TTSDKJSON_OK; }

static int onStringElement(__unused const char *const name, __unused const char *const value,
                           __unused void *const userData)
{
    return TTSDKJSON_OK;
}

static int onBeginObject(__unused const char *const name, __unused void *const userData) { return TTSDKJSON_OK; }

static int onBeginArray(__unused const char *const name, __unused void *const userData) { return TTSDKJSON_OK; }

static int onEndContainer(__unused void *const userData) { return TTSDKJSON_OK; }

static int onEndData(__unused void *const userData) { return TTSDKJSON_OK; }

/** Callback for adding JSON data.
 */
static int addJSONData(const char *const data, const int length, void *const userData)
{
    const int fd = *((int *)userData);
    const bool success = ttsdkfu_writeBytesToFD(fd, data, length);
    return success ? TTSDKJSON_OK : TTSDKJSON_ERROR_CANNOT_ADD_DATA;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

static double getCurrentTime(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + (double)tv.tv_usec / 1000000.0;
}

static double timeSince(double timeInSeconds) { return getCurrentTime() - timeInSeconds; }

/** Load the persistent state portion of a crash context.
 *
 * @param path The path to the file to read.
 *
 * @return true if the operation was successful.
 */
static bool loadState(const char *const path)
{
    // Stop if the file doesn't exist.
    // This is expected on the first run of the app.
    const int fd = open(path, O_RDONLY);
    if (fd < 0) {
        return false;
    }
    close(fd);

    char *data;
    int length;
    if (!ttsdkfu_readEntireFile(path, &data, &length, 50000)) {
        TTSDKLOG_ERROR("%s: Could not load file", path);
        return false;
    }

    TTSDKJSONDecodeCallbacks callbacks;
    callbacks.onBeginArray = onBeginArray;
    callbacks.onBeginObject = onBeginObject;
    callbacks.onBooleanElement = onBooleanElement;
    callbacks.onEndContainer = onEndContainer;
    callbacks.onEndData = onEndData;
    callbacks.onFloatingPointElement = onFloatingPointElement;
    callbacks.onIntegerElement = onIntegerElement;
    callbacks.onUnsignedIntegerElement = onUnsignedIntegerElement;
    callbacks.onNullElement = onNullElement;
    callbacks.onStringElement = onStringElement;

    int errorOffset = 0;

    char stringBuffer[1000];
    const int result =
        ttsdkjson_decode(data, (int)length, stringBuffer, sizeof(stringBuffer), &callbacks, &g_state, &errorOffset);
    free(data);
    if (result != TTSDKJSON_OK) {
        TTSDKLOG_ERROR("%s, offset %d: %s", path, errorOffset, ttsdkjson_stringForError(result));
        return false;
    }
    return true;
}

/** Save the persistent state portion of a crash context.
 *
 * @param path The path to the file to create.
 *
 * @return true if the operation was successful.
 */
static bool saveState(const char *const path)
{
    int fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        TTSDKLOG_ERROR("Could not open file %s for writing: %s", path, strerror(errno));
        return false;
    }

    TTSDKJSONEncodeContext JSONContext;
    ttsdkjson_beginEncode(&JSONContext, true, addJSONData, &fd);

    int result;
    if ((result = ttsdkjson_beginObject(&JSONContext, NULL)) != TTSDKJSON_OK) {
        goto done;
    }
    if ((result = ttsdkjson_addIntegerElement(&JSONContext, kKeyFormatVersion, kFormatVersion)) != TTSDKJSON_OK) {
        goto done;
    }
    // Record this launch crashed state into "crashed last launch" field.
    if ((result = ttsdkjson_addBooleanElement(&JSONContext, kKeyCrashedLastLaunch, g_state.crashedThisLaunch)) !=
        TTSDKJSON_OK) {
        goto done;
    }
    if ((result = ttsdkjson_addFloatingPointElement(&JSONContext, kKeyActiveDurationSinceLastCrash,
                                                 g_state.activeDurationSinceLastCrash)) != TTSDKJSON_OK) {
        goto done;
    }
    if ((result = ttsdkjson_addFloatingPointElement(&JSONContext, kKeyBackgroundDurationSinceLastCrash,
                                                 g_state.backgroundDurationSinceLastCrash)) != TTSDKJSON_OK) {
        goto done;
    }
    if ((result = ttsdkjson_addIntegerElement(&JSONContext, kKeyLaunchesSinceLastCrash, g_state.launchesSinceLastCrash)) !=
        TTSDKJSON_OK) {
        goto done;
    }
    if ((result = ttsdkjson_addIntegerElement(&JSONContext, kKeySessionsSinceLastCrash, g_state.sessionsSinceLastCrash)) !=
        TTSDKJSON_OK) {
        goto done;
    }
    result = ttsdkjson_endEncode(&JSONContext);

done:
    close(fd);
    if (result != TTSDKJSON_OK) {
        TTSDKLOG_ERROR("%s: %s", path, ttsdkjson_stringForError(result));
        return false;
    }
    return true;
}

static void updateAppState(void)
{
    const double duration = timeSince(g_state.appStateTransitionTime);
    g_state.appStateTransitionTime = getCurrentTime();

    if (g_state.applicationIsActive) {
        TTSDKLOG_TRACE("Updating activeDurationSinceLaunch: %f and activeDurationSinceLastCrash: %f with duration: %f",
                    g_state.activeDurationSinceLaunch, g_state.activeDurationSinceLastCrash, duration);
        g_state.activeDurationSinceLaunch += duration;
        g_state.activeDurationSinceLastCrash += duration;
    } else if (!g_state.applicationIsInForeground) {
        TTSDKLOG_TRACE(
            "Updating backgroundDurationSinceLaunch: %f and backgroundDurationSinceLastCrash: %f with duration: %f",
            g_state.backgroundDurationSinceLaunch, g_state.backgroundDurationSinceLastCrash, duration);
        g_state.backgroundDurationSinceLaunch += duration;
        g_state.backgroundDurationSinceLastCrash += duration;
    }
}

// ============================================================================
#pragma mark - API -
// ============================================================================

void ttsdkcrashstate_initialize(const char *const stateFilePath)
{
    g_stateFilePath = strdup(stateFilePath);
    loadState(g_stateFilePath);
}

bool ttsdkcrashstate_reset(void)
{
    if (g_isEnabled) {
        g_state.sessionsSinceLaunch = 1;
        g_state.activeDurationSinceLaunch = 0;
        g_state.backgroundDurationSinceLaunch = 0;
        if (g_state.crashedLastLaunch) {
            g_state.activeDurationSinceLastCrash = 0;
            g_state.backgroundDurationSinceLastCrash = 0;
            g_state.launchesSinceLastCrash = 0;
            g_state.sessionsSinceLastCrash = 0;
        }
        g_state.crashedThisLaunch = false;

        // Simulate first transition to foreground
        g_state.launchesSinceLastCrash++;
        g_state.sessionsSinceLastCrash++;
        g_state.applicationIsInForeground = true;

        return saveState(g_stateFilePath);
    }
    return false;
}

void ttsdkcrashstate_notifyObjCLoad(void)
{
    TTSDKLOG_TRACE("TTSDKCrash has been loaded!");
    memset(&g_state, 0, sizeof(g_state));
    g_state.applicationIsInForeground = false;
    g_state.applicationIsActive = true;
    g_state.appStateTransitionTime = getCurrentTime();
}

void ttsdkcrashstate_notifyAppActive(const bool isActive)
{
    if (g_isEnabled) {
        g_state.applicationIsActive = isActive;
        if (isActive) {
            TTSDKLOG_TRACE("Updating transition time from: %f to: %f", g_state.appStateTransitionTime, getCurrentTime());
            g_state.appStateTransitionTime = getCurrentTime();
        } else {
            double duration = timeSince(g_state.appStateTransitionTime);
            TTSDKLOG_TRACE("Updating activeDurationSinceLaunch: %f and activeDurationSinceLastCrash: %f with duration: %f",
                        g_state.activeDurationSinceLaunch, g_state.activeDurationSinceLastCrash, duration);
            g_state.activeDurationSinceLaunch += duration;
            g_state.activeDurationSinceLastCrash += duration;
        }
    }
}

void ttsdkcrashstate_notifyAppInForeground(const bool isInForeground)
{
    if (g_isEnabled) {
        const char *const stateFilePath = g_stateFilePath;

        g_state.applicationIsInForeground = isInForeground;
        if (isInForeground) {
            double duration = getCurrentTime() - g_state.appStateTransitionTime;
            TTSDKLOG_TRACE(
                "Updating backgroundDurationSinceLaunch: %f and backgroundDurationSinceLastCrash: %f with duration: %f",
                g_state.backgroundDurationSinceLaunch, g_state.backgroundDurationSinceLastCrash, duration);
            g_state.backgroundDurationSinceLaunch += duration;
            g_state.backgroundDurationSinceLastCrash += duration;
            g_state.sessionsSinceLastCrash++;
            g_state.sessionsSinceLaunch++;
        } else {
            g_state.appStateTransitionTime = getCurrentTime();
            saveState(stateFilePath);
        }
    }
}

void ttsdkcrashstate_notifyAppTerminate(void)
{
    if (g_isEnabled) {
        const char *const stateFilePath = g_stateFilePath;
        updateAppState();
        saveState(stateFilePath);
    }
}

void ttsdkcrashstate_notifyAppCrash(void)
{
    TTSDKLOG_TRACE("Trying to update AppState. g_isEnabled: %d", g_isEnabled);
    if (g_isEnabled) {
        const char *const stateFilePath = g_stateFilePath;
        updateAppState();
        g_state.crashedThisLaunch = true;
        saveState(stateFilePath);
    }
}

const TTSDKCrash_AppState *const ttsdkcrashstate_currentState(void) { return &g_state; }

static const char *monitorId(void) { return "ApplicationState"; }

static void setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            ttsdkcrashstate_reset();
        }
    }
}

static bool isEnabled(void) { return g_isEnabled; }

static void addContextualInfoToEvent(TTSDKCrash_MonitorContext *eventContext)
{
    if (g_isEnabled) {
        updateAppState();
        eventContext->AppState.activeDurationSinceLastCrash = g_state.activeDurationSinceLastCrash;
        eventContext->AppState.activeDurationSinceLaunch = g_state.activeDurationSinceLaunch;
        eventContext->AppState.applicationIsActive = g_state.applicationIsActive;
        eventContext->AppState.applicationIsInForeground = g_state.applicationIsInForeground;
        eventContext->AppState.appStateTransitionTime = g_state.appStateTransitionTime;
        eventContext->AppState.backgroundDurationSinceLastCrash = g_state.backgroundDurationSinceLastCrash;
        eventContext->AppState.backgroundDurationSinceLaunch = g_state.backgroundDurationSinceLaunch;
        eventContext->AppState.crashedLastLaunch = g_state.crashedLastLaunch;
        eventContext->AppState.crashedThisLaunch = g_state.crashedThisLaunch;
        eventContext->AppState.launchesSinceLastCrash = g_state.launchesSinceLastCrash;
        eventContext->AppState.sessionsSinceLastCrash = g_state.sessionsSinceLastCrash;
        eventContext->AppState.sessionsSinceLaunch = g_state.sessionsSinceLaunch;
    }
}

TTSDKCrashMonitorAPI *ttsdkcm_appstate_getAPI(void)
{
    static TTSDKCrashMonitorAPI api = { .monitorId = monitorId,
                                     .setEnabled = setEnabled,
                                     .isEnabled = isEnabled,
                                     .addContextualInfoToEvent = addContextualInfoToEvent };
    return &api;
}
