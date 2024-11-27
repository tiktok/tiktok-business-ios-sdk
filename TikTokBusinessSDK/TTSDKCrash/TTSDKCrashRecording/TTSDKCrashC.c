//
//  TTSDKCrashC.c
//
//  Created by Karl Stenerud on 2012-01-28.
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

#include "TTSDKCrashC.h"

#include "TTSDKCrashCachedData.h"
#include "TTSDKCrashMonitorContext.h"
#include "TTSDKCrashMonitorType.h"
#include "TTSDKCrashMonitor_AppState.h"
#include "TTSDKCrashMonitor_CPPException.h"
#include "TTSDKCrashMonitor_Deadlock.h"
#include "TTSDKCrashMonitor_MachException.h"
#include "TTSDKCrashMonitor_Memory.h"
#include "TTSDKCrashMonitor_NSException.h"
#include "TTSDKCrashMonitor_Signal.h"
#include "TTSDKCrashMonitor_System.h"
#include "TTSDKCrashMonitor_User.h"
#include "TTSDKCrashMonitor_Zombie.h"
#include "TTSDKCrashReportC.h"
#include "TTSDKCrashReportFixer.h"
#include "TTSDKCrashReportStoreC+Private.h"
#include "TTSDKFileUtils.h"
#include "TTSDKObjC.h"
#include "TTSDKString.h"
#include "TTSDKSystemCapabilities.h"

// #define TTSDKLogger_LocalLevel TRACE
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "TTSDKLogger.h"

#define TTSDKC_MAX_APP_NAME_LENGTH 100

typedef enum {
    TTSDKApplicationStateNone,
    TTSDKApplicationStateDidBecomeActive,
    TTSDKApplicationStateWillResignActiveActive,
    TTSDKApplicationStateDidEnterBackground,
    TTSDKApplicationStateWillEnterForeground,
    TTSDKApplicationStateWillTerminate
} TTSDKApplicationState;

static const struct TTSDKCrashMonitorMapping {
    TTSDKCrashMonitorType type;
    TTSDKCrashMonitorAPI *(*getAPI)(void);
} g_monitorMappings[] = { { TTSDKCrashMonitorTypeMachException, ttsdkcm_machexception_getAPI },
                          { TTSDKCrashMonitorTypeSignal, ttsdkcm_signal_getAPI },
                          { TTSDKCrashMonitorTypeCPPException, ttsdkcm_cppexception_getAPI },
                          { TTSDKCrashMonitorTypeNSException, ttsdkcm_nsexception_getAPI },
                          { TTSDKCrashMonitorTypeMainThreadDeadlock, ttsdkcm_deadlock_getAPI },
                          { TTSDKCrashMonitorTypeUserReported, ttsdkcm_user_getAPI },
                          { TTSDKCrashMonitorTypeSystem, ttsdkcm_system_getAPI },
                          { TTSDKCrashMonitorTypeApplicationState, ttsdkcm_appstate_getAPI },
                          { TTSDKCrashMonitorTypeZombie, ttsdkcm_zombie_getAPI },
                          { TTSDKCrashMonitorTypeMemoryTermination, ttsdkcm_memory_getAPI } };

static const size_t g_monitorMappingCount = sizeof(g_monitorMappings) / sizeof(g_monitorMappings[0]);

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if TTSDKCrash has been installed. */
static volatile bool g_installed = 0;

static bool g_shouldAddConsoleLogToReport = false;
static bool g_shouldPrintPreviousLog = false;
static char g_consoleLogPath[TTSDKFU_MAX_PATH_LENGTH];
static TTSDKCrashMonitorType g_monitoring = TTSDKCrashMonitorTypeProductionSafeMinimal;
static char g_lastCrashReportFilePath[TTSDKFU_MAX_PATH_LENGTH];
static TTSDKCrashReportStoreCConfiguration g_reportStoreConfig;
static TTSDKReportWrittenCallback g_reportWrittenCallback;
static TTSDKApplicationState g_lastApplicationState = TTSDKApplicationStateNone;

// ============================================================================
#pragma mark - Utility -
// ============================================================================

static void printPreviousLog(const char *filePath)
{
    char *data;
    int length;
    if (ttsdkfu_readEntireFile(filePath, &data, &length, 0)) {
        printf("\nvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv Previous Log vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n\n");
        printf("%s\n", data);
        free(data);
        printf("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n");
        fflush(stdout);
    }
}

static void notifyOfBeforeInstallationState(void)
{
    TTSDKLOG_DEBUG("Notifying of pre-installation state");
    switch (g_lastApplicationState) {
        case TTSDKApplicationStateDidBecomeActive:
            return ttsdkcrash_notifyAppActive(true);
        case TTSDKApplicationStateWillResignActiveActive:
            return ttsdkcrash_notifyAppActive(false);
        case TTSDKApplicationStateDidEnterBackground:
            return ttsdkcrash_notifyAppInForeground(false);
        case TTSDKApplicationStateWillEnterForeground:
            return ttsdkcrash_notifyAppInForeground(true);
        case TTSDKApplicationStateWillTerminate:
            return ttsdkcrash_notifyAppTerminate();
        default:
            return;
    }
}

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Called when a crash occurs.
 *
 * This function gets passed as a callback to a crash handler.
 */
static void onCrash(struct TTSDKCrash_MonitorContext *monitorContext)
{
    if (monitorContext->currentSnapshotUserReported == false) {
        TTSDKLOG_DEBUG("Updating application state to note crash.");
        ttsdkcrashstate_notifyAppCrash();
    }
    monitorContext->consoleLogPath = g_shouldAddConsoleLogToReport ? g_consoleLogPath : NULL;
    if (monitorContext->crashedDuringCrashHandling) {
        ttsdkcrashreport_writeRecrashReport(monitorContext, g_lastCrashReportFilePath);
    } else if (monitorContext->reportPath) {
        ttsdkcrashreport_writeStandardReport(monitorContext, monitorContext->reportPath);
    } else {
        char crashReportFilePath[TTSDKFU_MAX_PATH_LENGTH];
        int64_t reportID = ttsdkcrs_getNextCrashReport(crashReportFilePath, &g_reportStoreConfig);
        strncpy(g_lastCrashReportFilePath, crashReportFilePath, sizeof(g_lastCrashReportFilePath));
        ttsdkcrashreport_writeStandardReport(monitorContext, crashReportFilePath);

        if (g_reportWrittenCallback) {
            g_reportWrittenCallback(reportID);
        }
    }
}

static void setMonitors(TTSDKCrashMonitorType monitorTypes)
{
    g_monitoring = monitorTypes;

    for (size_t i = 0; i < g_monitorMappingCount; i++) {
        TTSDKCrashMonitorAPI *api = g_monitorMappings[i].getAPI();
        if (api != NULL) {
            if (monitorTypes & g_monitorMappings[i].type) {
                ttsdkcm_addMonitor(api);
            } else {
                ttsdkcm_removeMonitor(api);
            }
        }
    }
}

void handleConfiguration(TTSDKCrashCConfiguration *configuration)
{
    g_reportStoreConfig = TTSDKCrashReportStoreCConfiguration_Copy(&configuration->reportStoreConfiguration);

    if (configuration->userInfoJSON != NULL) {
        ttsdkcrashreport_setUserInfoJSON(configuration->userInfoJSON);
    }
#if TTSDKCRASH_HAS_OBJC
    ttsdkcm_setDeadlockHandlerWatchdogInterval(configuration->deadlockWatchdogInterval);
#endif
    ttsdkccd_setSearchQueueNames(configuration->enableQueueNameSearch);
    ttsdkcrashreport_setIntrospectMemory(configuration->enableMemoryIntrospection);
    ttsdkcm_signal_sigterm_setMonitoringEnabled(configuration->enableSigTermMonitoring);

    if (configuration->doNotIntrospectClasses.strings != NULL) {
        ttsdkcrashreport_setDoNotIntrospectClasses(configuration->doNotIntrospectClasses.strings,
                                                configuration->doNotIntrospectClasses.length);
    }

    ttsdkcrashreport_setUserSectionWriteCallback(configuration->crashNotifyCallback);
    g_reportWrittenCallback = configuration->reportWrittenCallback;
    g_shouldAddConsoleLogToReport = configuration->addConsoleLogToReport;
    g_shouldPrintPreviousLog = configuration->printPreviousLogOnStartup;

    if (configuration->enableSwapCxaThrow) {
        ttsdkcm_enableSwapCxaThrow();
    }
}
// ============================================================================
#pragma mark - API -
// ============================================================================

TTSDKCrashInstallErrorCode ttsdkcrash_install(const char *appName, const char *const installPath,
                                        TTSDKCrashCConfiguration *configuration)
{
    TTSDKLOG_DEBUG("Installing crash reporter.");

    if (g_installed) {
        TTSDKLOG_DEBUG("Crash reporter already installed.");
        return TTSDKCrashInstallErrorAlreadyInstalled;
    }

    if (appName == NULL || installPath == NULL) {
        TTSDKLOG_ERROR("Invalid parameters: appName or installPath is NULL.");
        return TTSDKCrashInstallErrorInvalidParameter;
    }

    handleConfiguration(configuration);

    if (g_reportStoreConfig.appName == NULL) {
        g_reportStoreConfig.appName = strdup(appName);
    }

    char path[TTSDKFU_MAX_PATH_LENGTH];
    if (g_reportStoreConfig.reportsPath == NULL) {
        if (snprintf(path, sizeof(path), "%s/" TTSDKCRS_DEFAULT_REPORTS_FOLDER, installPath) >= (int)sizeof(path)) {
            TTSDKLOG_ERROR("Reports path is too long.");
            return TTSDKCrashInstallErrorPathTooLong;
        }
        g_reportStoreConfig.reportsPath = strdup(path);
    }

    ttsdkcrs_initialize(&g_reportStoreConfig);

    if (snprintf(path, sizeof(path), "%s/Data", installPath) >= (int)sizeof(path)) {
        TTSDKLOG_ERROR("Data path is too long.");
        return TTSDKCrashInstallErrorPathTooLong;
    }
    if (ttsdkfu_makePath(path) == false) {
        TTSDKLOG_ERROR("Could not create path: %s", path);
        return TTSDKCrashInstallErrorCouldNotCreatePath;
    }
    ttsdkmemory_initialize(path);

    if (snprintf(path, sizeof(path), "%s/Data/CrashState.json", installPath) >= (int)sizeof(path)) {
        TTSDKLOG_ERROR("Crash state path is too long.");
        return TTSDKCrashInstallErrorPathTooLong;
    }
    ttsdkcrashstate_initialize(path);

    if (snprintf(g_consoleLogPath, sizeof(g_consoleLogPath), "%s/Data/ConsoleLog.txt", installPath) >=
        (int)sizeof(g_consoleLogPath)) {
        TTSDKLOG_ERROR("Console log path is too long.");
        return TTSDKCrashInstallErrorPathTooLong;
    }
    if (g_shouldPrintPreviousLog) {
        printPreviousLog(g_consoleLogPath);
    }
    ttsdklog_setLogFilename(g_consoleLogPath, true);

    ttsdkccd_init(60);

    ttsdkcm_setEventCallback(onCrash);
    setMonitors(configuration->monitors);
    if (ttsdkcm_activateMonitors() == false) {
        TTSDKLOG_ERROR("No crash monitors are active");
        return TTSDKCrashInstallErrorNoActiveMonitors;
    }

    g_installed = true;
    TTSDKLOG_DEBUG("Installation complete.");

    notifyOfBeforeInstallationState();
    return TTSDKCrashInstallErrorNone;
}

void ttsdkcrash_setUserInfoJSON(const char *const userInfoJSON) { ttsdkcrashreport_setUserInfoJSON(userInfoJSON); }

const char *ttsdkcrash_getUserInfoJSON(void) { return ttsdkcrashreport_getUserInfoJSON(); }

void ttsdkcrash_reportUserException(const char *name, const char *reason, const char *language, const char *lineOfCode,
                                 const char *stackTrace, bool logAllThreads, bool terminateProgram)
{
    ttsdkcm_reportUserException(name, reason, language, lineOfCode, stackTrace, logAllThreads, terminateProgram);
    if (g_shouldAddConsoleLogToReport) {
        ttsdklog_clearLogFile();
    }
}

void ttsdkcrash_notifyObjCLoad(void) { ttsdkcrashstate_notifyObjCLoad(); }

void ttsdkcrash_notifyAppActive(bool isActive)
{
    if (g_installed) {
        ttsdkcrashstate_notifyAppActive(isActive);
    }
    g_lastApplicationState = isActive ? TTSDKApplicationStateDidBecomeActive : TTSDKApplicationStateWillResignActiveActive;
}

void ttsdkcrash_notifyAppInForeground(bool isInForeground)
{
    if (g_installed) {
        ttsdkcrashstate_notifyAppInForeground(isInForeground);
    }
    g_lastApplicationState =
        isInForeground ? TTSDKApplicationStateWillEnterForeground : TTSDKApplicationStateDidEnterBackground;
}

void ttsdkcrash_notifyAppTerminate(void)
{
    if (g_installed) {
        ttsdkcrashstate_notifyAppTerminate();
    }
    g_lastApplicationState = TTSDKApplicationStateWillTerminate;
}

void ttsdkcrash_notifyAppCrash(void) { ttsdkcrashstate_notifyAppCrash(); }

int64_t ttsdkcrash_addUserReport(const char *report, int reportLength)
{
    return ttsdkcrs_addUserReport(report, reportLength, &g_reportStoreConfig);
}
