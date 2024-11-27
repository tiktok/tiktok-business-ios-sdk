//
//  TTSDKCrashMonitor_Signal.c
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

#include "TTSDKCrashMonitor_Signal.h"

#include "TTSDKCrashMonitorContext.h"
#include "TTSDKCrashMonitorContextHelper.h"
#include "TTSDKCrashMonitorHelper.h"
#include "TTSDKCrashMonitor_MachException.h"
#include "TTSDKCrashMonitor_Memory.h"
#include "TTSDKID.h"
#include "TTSDKMachineContext.h"
#include "TTSDKSignalInfo.h"
#include "TTSDKStackCursor_MachineContext.h"
#include "TTSDKSystemCapabilities.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

#if TTSDKCRASH_HAS_SIGNAL

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = false;
static bool g_sigterm_monitoringEnabled = false;

static TTSDKCrash_MonitorContext g_monitorContext;
static TTSDKStackCursor g_stackCursor;

#if TTSDKCRASH_HAS_SIGNAL_STACK
/** Our custom signal stack. The signal handler will use this as its stack. */
static stack_t g_signalStack = { 0 };
#endif

/** Signal handlers that were installed before we installed ours. */
static struct sigaction *g_previousSignalHandlers = NULL;

static char g_eventID[37];

// ============================================================================
#pragma mark - Private -
// ============================================================================

static void uninstallSignalHandler(void);
static bool shouldHandleSignal(int sigNum) { return !(sigNum == SIGTERM && !g_sigterm_monitoringEnabled); }

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

/** Our custom signal handler.
 * Restore the default signal handlers, record the signal information, and
 * write a crash report.
 * Once we're done, re-raise the signal and let the default handlers deal with
 * it.
 *
 * @param sigNum The signal that was raised.
 *
 * @param signalInfo Information about the signal.
 *
 * @param userContext Other contextual information.
 */
static void handleSignal(int sigNum, siginfo_t *signalInfo, void *userContext)
{
    TTSDKLOG_DEBUG("Trapped signal %d", sigNum);
    if (g_isEnabled && shouldHandleSignal(sigNum)) {
        thread_act_array_t threads = NULL;
        mach_msg_type_number_t numThreads = 0;
        ttsdkmc_suspendEnvironment(&threads, &numThreads);
        ttsdkcm_notifyFatalExceptionCaptured(false);

        TTSDKLOG_DEBUG("Filling out context.");
        TTSDKMC_NEW_CONTEXT(machineContext);
        ttsdkmc_getContextForSignal(userContext, machineContext);
        ttsdttsdkc_initWithMachineContext(&g_stackCursor, TTSDKSC_MAX_STACK_DEPTH, machineContext);

        TTSDKCrash_MonitorContext *crashContext = &g_monitorContext;
        memset(crashContext, 0, sizeof(*crashContext));
        ttsdkmc_fillMonitorContext(crashContext, ttsdkcm_signal_getAPI());
        crashContext->eventID = g_eventID;
        crashContext->offendingMachineContext = machineContext;
        crashContext->registersAreValid = true;
        crashContext->faultAddress = (uintptr_t)signalInfo->si_addr;
        crashContext->signal.userContext = userContext;
        crashContext->signal.signum = signalInfo->si_signo;
        crashContext->signal.sigcode = signalInfo->si_code;
        crashContext->stackCursor = &g_stackCursor;

        ttsdkcm_handleException(crashContext);
        ttsdkmc_resumeEnvironment(threads, numThreads);
    } else {
        uninstallSignalHandler();
        ttsdkmemory_notifyUnhandledFatalSignal();
    }

    TTSDKLOG_DEBUG("Re-raising signal for regular handlers to catch.");
    raise(sigNum);
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static bool installSignalHandler(void)
{
    TTSDKLOG_DEBUG("Installing signal handler.");

#if TTSDKCRASH_HAS_SIGNAL_STACK

    if (g_signalStack.ss_size == 0) {
        TTSDKLOG_DEBUG("Allocating signal stack area.");
        g_signalStack.ss_size = SIGSTKSZ;
        g_signalStack.ss_sp = malloc(g_signalStack.ss_size);
    }

    TTSDKLOG_DEBUG("Setting signal stack area.");
    if (sigaltstack(&g_signalStack, NULL) != 0) {
        TTSDKLOG_ERROR("signalstack: %s", strerror(errno));
        goto failed;
    }
#endif

    const int *fatalSignals = ttsdksignal_fatalSignals();
    int fatalSignalsCount = ttsdksignal_numFatalSignals();

    if (g_previousSignalHandlers == NULL) {
        TTSDKLOG_DEBUG("Allocating memory to store previous signal handlers.");
        g_previousSignalHandlers = malloc(sizeof(*g_previousSignalHandlers) * (unsigned)fatalSignalsCount);
    }

    struct sigaction action = { { 0 } };
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#if TTSDKCRASH_HOST_APPLE && defined(__LP64__)
    action.sa_flags |= SA_64REGSET;
#endif
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = &handleSignal;

    for (int i = 0; i < fatalSignalsCount; i++) {
        TTSDKLOG_DEBUG("Assigning handler for signal %d", fatalSignals[i]);
        if (sigaction(fatalSignals[i], &action, &g_previousSignalHandlers[i]) != 0) {
            char sigNameBuff[30];
            const char *sigName = ttsdksignal_signalName(fatalSignals[i]);
            if (sigName == NULL) {
                snprintf(sigNameBuff, sizeof(sigNameBuff), "%d", fatalSignals[i]);
                sigName = sigNameBuff;
            }
            TTSDKLOG_ERROR("sigaction (%s): %s", sigName, strerror(errno));
            // Try to reverse the damage
            for (i--; i >= 0; i--) {
                sigaction(fatalSignals[i], &g_previousSignalHandlers[i], NULL);
            }
            goto failed;
        }
    }
    TTSDKLOG_DEBUG("Signal handlers installed.");
    return true;

failed:
    TTSDKLOG_DEBUG("Failed to install signal handlers.");
    return false;
}

static void uninstallSignalHandler(void)
{
    TTSDKLOG_DEBUG("Uninstalling signal handlers.");

    const int *fatalSignals = ttsdksignal_fatalSignals();
    int fatalSignalsCount = ttsdksignal_numFatalSignals();

    for (int i = 0; i < fatalSignalsCount; i++) {
        TTSDKLOG_DEBUG("Restoring original handler for signal %d", fatalSignals[i]);
        sigaction(fatalSignals[i], &g_previousSignalHandlers[i], NULL);
    }

#if TTSDKCRASH_HAS_SIGNAL_STACK
    g_signalStack = (stack_t) { 0 };
#endif
    TTSDKLOG_DEBUG("Signal handlers uninstalled.");
}

static const char *monitorId(void) { return "Signal"; }

static TTSDKCrashMonitorFlag monitorFlags(void) { return TTSDKCrashMonitorFlagFatal | TTSDKCrashMonitorFlagAsyncSafe; }

static void setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            ttsdkid_generate(g_eventID);
            if (!installSignalHandler()) {
                return;
            }
        } else {
            uninstallSignalHandler();
        }
    }
}

static bool isEnabled(void) { return g_isEnabled; }

static void addContextualInfoToEvent(struct TTSDKCrash_MonitorContext *eventContext)
{
    const char *machName = ttsdkcm_getMonitorId(ttsdkcm_machexception_getAPI());

    if (!(strcmp(eventContext->monitorId, monitorId()) == 0 ||
          (machName && strcmp(eventContext->monitorId, machName) == 0))) {
        eventContext->signal.signum = SIGABRT;
    }
}

#endif /* TTSDKCRASH_HAS_SIGNAL */

void ttsdkcm_signal_sigterm_setMonitoringEnabled(bool enabled)
{
#if TTSDKCRASH_HAS_SIGNAL
    g_sigterm_monitoringEnabled = enabled;
#endif
}

TTSDKCrashMonitorAPI *ttsdkcm_signal_getAPI(void)
{
#if TTSDKCRASH_HAS_SIGNAL
    static TTSDKCrashMonitorAPI api = { .monitorId = monitorId,
                                     .monitorFlags = monitorFlags,
                                     .setEnabled = setEnabled,
                                     .isEnabled = isEnabled,
                                     .addContextualInfoToEvent = addContextualInfoToEvent };
    return &api;
#else
    return NULL;
#endif
}
