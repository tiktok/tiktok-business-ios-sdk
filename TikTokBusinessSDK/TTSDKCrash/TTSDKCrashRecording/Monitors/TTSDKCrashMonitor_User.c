//
//  TTSDKCrashMonitor_User.c
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

#include "TTSDKCrashMonitor_User.h"

#include "TTSDKCrashMonitorContext.h"
#include "TTSDKCrashMonitorContextHelper.h"
#include "TTSDKID.h"
#include "TTSDKStackCursor_SelfThread.h"
#include "TTSDKThread.h"

// #define TTSDKLogger_LocalLevel TRACE
#include <memory.h>
#include <stdlib.h>

#include "TTSDKLogger.h"

/** Context to fill with crash information. */

static volatile bool g_isEnabled = false;

void ttsdkcm_reportUserException(const char *name, const char *reason, const char *language, const char *lineOfCode,
                              const char *stackTrace, bool logAllThreads, bool terminateProgram)
{
    if (!g_isEnabled) {
        TTSDKLOG_WARN("User-reported exception monitor is not installed. Exception has not been recorded.");
    } else {
        thread_act_array_t threads = NULL;
        mach_msg_type_number_t numThreads = 0;
        if (logAllThreads) {
            ttsdkmc_suspendEnvironment(&threads, &numThreads);
        }
        if (terminateProgram) {
            ttsdkcm_notifyFatalExceptionCaptured(false);
        }

        char eventID[37];
        ttsdkid_generate(eventID);
        TTSDKMC_NEW_CONTEXT(machineContext);
        ttsdkmc_getContextForThread(ttsdkthread_self(), machineContext, true);
        TTSDKStackCursor stackCursor;
        ttsdttsdkc_initSelfThread(&stackCursor, 0);

        TTSDKLOG_DEBUG("Filling out context.");
        TTSDKCrash_MonitorContext context;
        memset(&context, 0, sizeof(context));
        ttsdkmc_fillMonitorContext(&context, ttsdkcm_user_getAPI());
        context.eventID = eventID;
        context.offendingMachineContext = machineContext;
        context.registersAreValid = false;
        context.crashReason = reason;
        context.userException.name = name;
        context.userException.language = language;
        context.userException.lineOfCode = lineOfCode;
        context.userException.customStackTrace = stackTrace;
        context.stackCursor = &stackCursor;

        ttsdkcm_handleException(&context);

        if (logAllThreads) {
            ttsdkmc_resumeEnvironment(threads, numThreads);
        }
        if (terminateProgram) {
            abort();
        }
    }
}

static const char *monitorId(void) { return "UserReported"; }

static void setEnabled(bool isEnabled) { g_isEnabled = isEnabled; }

static bool isEnabled(void) { return g_isEnabled; }

TTSDKCrashMonitorAPI *ttsdkcm_user_getAPI(void)
{
    static TTSDKCrashMonitorAPI api = { .monitorId = monitorId, .setEnabled = setEnabled, .isEnabled = isEnabled };
    return &api;
}
