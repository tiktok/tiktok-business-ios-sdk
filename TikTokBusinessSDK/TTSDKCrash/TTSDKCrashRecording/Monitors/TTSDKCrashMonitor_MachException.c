//
//  TTSDKCrashMonitor_MachException.c
//
//  Created by Karl Stenerud on 2012-02-04.
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

#include "TTSDKCrashMonitor_MachException.h"

#include "TTSDKCPU.h"
#include "TTSDKCrashMonitorContext.h"
#include "TTSDKCrashMonitorContextHelper.h"
#include "TTSDKCrashMonitorHelper.h"
#include "TTSDKCrashMonitor_Signal.h"
#include "TTSDKID.h"
#include "TTSDKStackCursor_MachineContext.h"
#include "TTSDKSystemCapabilities.h"
#include "TTSDKThread.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

#if TTSDKCRASH_HAS_MACH

#include <mach/mach.h>
#include <pthread.h>
#include <signal.h>

// ============================================================================
#pragma mark - Constants -
// ============================================================================

static const char *kThreadPrimary = "TTSDKCrash Exception Handler (Primary)";
static const char *kThreadSecondary = "TTSDKCrash Exception Handler (Secondary)";

#if __LP64__
#define MACH_ERROR_CODE_MASK 0xFFFFFFFFFFFFFFFF
#else
#define MACH_ERROR_CODE_MASK 0xFFFFFFFF
#endif

// ============================================================================
#pragma mark - Types -
// ============================================================================

/** A mach exception message (according to ux_exception.c, xnu-1699.22.81).
 */
#pragma pack(4)
typedef struct {
    /** Mach header. */
    mach_msg_header_t header;

    // Start of the kernel processed data.

    /** Basic message body data. */
    mach_msg_body_t body;

    /** The thread that raised the exception. */
    mach_msg_port_descriptor_t thread;

    /** The task that raised the exception. */
    mach_msg_port_descriptor_t task;

    // End of the kernel processed data.

    /** Network Data Representation. */
    NDR_record_t NDR;

    /** The exception that was raised. */
    exception_type_t exception;

    /** The number of codes. */
    mach_msg_type_number_t codeCount;

    /** Exception code and subcode. */
    // ux_exception.c defines this as mach_exception_data_t for some reason.
    // But it's not actually a pointer; it's an embedded array.
    // On 32-bit systems, only the lower 32 bits of the code and subcode
    // are valid.
    mach_exception_data_type_t code[0];

    /** Padding to avoid RCV_TOO_LARGE. */
    char padding[512];
} MachExceptionMessage;
#pragma pack()

/** A mach reply message (according to ux_exception.c, xnu-1699.22.81).
 */
#pragma pack(4)
typedef struct {
    /** Mach header. */
    mach_msg_header_t header;

    /** Network Data Representation. */
    NDR_record_t NDR;

    /** Return code. */
    kern_return_t returnCode;
} MachReplyMessage;
#pragma pack()

// ============================================================================
#pragma mark - Globals -
// ============================================================================

static volatile bool g_isEnabled = false;

static TTSDKCrash_MonitorContext g_monitorContext;
static TTSDKStackCursor g_stackCursor;

static bool g_isHandlingCrash = false;

/** Holds exception port info regarding the previously installed exception
 * handlers.
 */
static struct {
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_handler_t ports[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t count;
} g_previousExceptionPorts;

/** Our exception port. */
static mach_port_t g_exceptionPort = MACH_PORT_NULL;

/** Primary exception handler thread. */
static pthread_t g_primaryPThread;
static thread_t g_primaryMachThread;

/** Secondary exception handler thread in case crash handler crashes. */
static pthread_t g_secondaryPThread;
static thread_t g_secondaryMachThread;

static char g_primaryEventID[37];
static char g_secondaryEventID[37];

// ============================================================================
#pragma mark - Utility -
// ============================================================================

/** Restore the original mach exception ports.
 */
static void restoreExceptionPorts(void)
{
    TTSDKLOG_DEBUG("Restoring original exception ports.");
    if (g_previousExceptionPorts.count == 0) {
        TTSDKLOG_DEBUG("Original exception ports were already restored.");
        return;
    }

    const task_t thisTask = mach_task_self();
    kern_return_t kr;

    // Reinstall old exception ports.
    for (mach_msg_type_number_t i = 0; i < g_previousExceptionPorts.count; i++) {
        TTSDKLOG_TRACE("Restoring port index %d", i);
        kr = task_set_exception_ports(thisTask, g_previousExceptionPorts.masks[i], g_previousExceptionPorts.ports[i],
                                      g_previousExceptionPorts.behaviors[i], g_previousExceptionPorts.flavors[i]);
        if (kr != KERN_SUCCESS) {
            TTSDKLOG_ERROR("task_set_exception_ports: %s", mach_error_string(kr));
        }
    }
    TTSDKLOG_DEBUG("Exception ports restored.");
    g_previousExceptionPorts.count = 0;
}

#define EXC_UNIX_BAD_SYSCALL 0x10000 /* SIGSYS */
#define EXC_UNIX_BAD_PIPE 0x10001    /* SIGPIPE */
#define EXC_UNIX_ABORT 0x10002       /* SIGABRT */

static int signalForMachException(exception_type_t exception, mach_exception_code_t code)
{
    switch (exception) {
        case EXC_ARITHMETIC:
            return SIGFPE;
        case EXC_BAD_ACCESS:
            return code == KERN_INVALID_ADDRESS ? SIGSEGV : SIGBUS;
        case EXC_BAD_INSTRUCTION:
            return SIGILL;
        case EXC_BREAKPOINT:
            return SIGTRAP;
        case EXC_EMULATION:
            return SIGEMT;
        case EXC_SOFTWARE: {
            switch (code) {
                case EXC_UNIX_BAD_SYSCALL:
                    return SIGSYS;
                case EXC_UNIX_BAD_PIPE:
                    return SIGPIPE;
                case EXC_UNIX_ABORT:
                    return SIGABRT;
                case EXC_SOFT_SIGNAL:
                    return SIGKILL;
            }
            break;
        }
    }
    return 0;
}

static exception_type_t machExceptionForSignal(int sigNum)
{
    switch (sigNum) {
        case SIGFPE:
            return EXC_ARITHMETIC;
        case SIGSEGV:
            return EXC_BAD_ACCESS;
        case SIGBUS:
            return EXC_BAD_ACCESS;
        case SIGILL:
            return EXC_BAD_INSTRUCTION;
        case SIGTRAP:
            return EXC_BREAKPOINT;
        case SIGEMT:
            return EXC_EMULATION;
        case SIGSYS:
            return EXC_UNIX_BAD_SYSCALL;
        case SIGPIPE:
            return EXC_UNIX_BAD_PIPE;
        case SIGABRT:
            // The Apple reporter uses EXC_CRASH instead of EXC_UNIX_ABORT
            return EXC_CRASH;
        case SIGKILL:
            return EXC_SOFT_SIGNAL;
    }
    return 0;
}

// ============================================================================
#pragma mark - Handler -
// ============================================================================

/** Our exception handler thread routine.
 * Wait for an exception message, uninstall our exception port, record the
 * exception information, and write a report.
 */
static void *handleExceptions(void *const userData)
{
    MachExceptionMessage exceptionMessage = { { 0 } };
    MachReplyMessage replyMessage = { { 0 } };
    char *eventID = g_primaryEventID;

    const char *threadName = (const char *)userData;
    pthread_setname_np(threadName);
    if (threadName == kThreadSecondary) {
        TTSDKLOG_DEBUG("This is the secondary thread. Suspending.");
        thread_suspend((thread_t)ttsdkthread_self());
        eventID = g_secondaryEventID;
    }

    for (;;) {
        TTSDKLOG_DEBUG("Waiting for mach exception");

        // Wait for a message.
        kern_return_t kr = mach_msg(&exceptionMessage.header, MACH_RCV_MSG, 0, sizeof(exceptionMessage),
                                    g_exceptionPort, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if (kr == KERN_SUCCESS) {
            break;
        }

        // Loop and try again on failure.
        TTSDKLOG_ERROR("mach_msg: %s", mach_error_string(kr));
    }

    TTSDKLOG_DEBUG("Trapped mach exception code 0x%llx, subcode 0x%llx", exceptionMessage.code[0],
                exceptionMessage.code[1]);
    if (g_isEnabled) {
        thread_act_array_t threads = NULL;
        mach_msg_type_number_t numThreads = 0;
        ttsdkmc_suspendEnvironment(&threads, &numThreads);
        g_isHandlingCrash = true;
        ttsdkcm_notifyFatalExceptionCaptured(true);

        TTSDKLOG_DEBUG("Exception handler is installed. Continuing exception handling.");

        // Switch to the secondary thread if necessary, or uninstall the handler
        // to avoid a death loop.
        if (ttsdkthread_self() == g_primaryMachThread) {
            TTSDKLOG_DEBUG("This is the primary exception thread. Activating secondary thread.");
            // TODO: This was put here to avoid a freeze. Does secondary thread ever fire?
            restoreExceptionPorts();
            if (thread_resume(g_secondaryMachThread) != KERN_SUCCESS) {
                TTSDKLOG_DEBUG("Could not activate secondary thread. Restoring original exception ports.");
            }
        } else {
            TTSDKLOG_DEBUG("This is the secondary exception thread.");  // Restoring original exception ports.");
                                                                     //            restoreExceptionPorts();
        }

        // Fill out crash information
        TTSDKLOG_DEBUG("Fetching machine state.");
        TTSDKMC_NEW_CONTEXT(machineContext);
        TTSDKCrash_MonitorContext *crashContext = &g_monitorContext;
        crashContext->offendingMachineContext = machineContext;
        ttsdttsdkc_initCursor(&g_stackCursor, NULL, NULL);
        if (ttsdkmc_getContextForThread(exceptionMessage.thread.name, machineContext, true)) {
            ttsdttsdkc_initWithMachineContext(&g_stackCursor, TTSDKSC_MAX_STACK_DEPTH, machineContext);
            TTSDKLOG_TRACE("Fault address %p, instruction address %p", ttsdkcpu_faultAddress(machineContext),
                        ttsdkcpu_instructionAddress(machineContext));
            if (exceptionMessage.exception == EXC_BAD_ACCESS) {
                crashContext->faultAddress = ttsdkcpu_faultAddress(machineContext);
            } else {
                crashContext->faultAddress = ttsdkcpu_instructionAddress(machineContext);
            }
        }

        TTSDKLOG_DEBUG("Filling out context.");
        ttsdkmc_fillMonitorContext(crashContext, ttsdkcm_machexception_getAPI());
        crashContext->eventID = eventID;
        crashContext->registersAreValid = true;
        crashContext->mach.type = exceptionMessage.exception;
        crashContext->mach.code = exceptionMessage.code[0] & (int64_t)MACH_ERROR_CODE_MASK;
        crashContext->mach.subcode = exceptionMessage.code[1] & (int64_t)MACH_ERROR_CODE_MASK;
        if (crashContext->mach.code == KERN_PROTECTION_FAILURE && crashContext->isStackOverflow) {
            // A stack overflow should return KERN_INVALID_ADDRESS, but
            // when a stack blasts through the guard pages at the top of the stack,
            // it generates KERN_PROTECTION_FAILURE. Correct for this.
            crashContext->mach.code = KERN_INVALID_ADDRESS;
        }
        crashContext->signal.signum = signalForMachException(crashContext->mach.type, crashContext->mach.code);
        crashContext->stackCursor = &g_stackCursor;

        ttsdkcm_handleException(crashContext);

        TTSDKLOG_DEBUG("Crash handling complete. Restoring original handlers.");
        g_isHandlingCrash = false;
        ttsdkmc_resumeEnvironment(threads, numThreads);
    }

    TTSDKLOG_DEBUG("Replying to mach exception message.");
    // Send a reply saying "I didn't handle this exception".
    replyMessage.header = exceptionMessage.header;
    replyMessage.NDR = exceptionMessage.NDR;
    replyMessage.returnCode = KERN_FAILURE;

    mach_msg(&replyMessage.header, MACH_SEND_MSG, sizeof(replyMessage), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE,
             MACH_PORT_NULL);

    return NULL;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

static void uninstallExceptionHandler(void)
{
    TTSDKLOG_DEBUG("Uninstalling mach exception handler.");

    // NOTE: Do not deallocate the exception port. If a secondary crash occurs
    // it will hang the process.

    restoreExceptionPorts();

    thread_t thread_self = (thread_t)ttsdkthread_self();

    if (g_primaryPThread != 0 && g_primaryMachThread != thread_self) {
        TTSDKLOG_DEBUG("Canceling primary exception thread.");
        if (g_isHandlingCrash) {
            thread_terminate(g_primaryMachThread);
        } else {
            pthread_cancel(g_primaryPThread);
        }
        g_primaryMachThread = 0;
        g_primaryPThread = 0;
    }
    if (g_secondaryPThread != 0 && g_secondaryMachThread != thread_self) {
        TTSDKLOG_DEBUG("Canceling secondary exception thread.");
        if (g_isHandlingCrash) {
            thread_terminate(g_secondaryMachThread);
        } else {
            pthread_cancel(g_secondaryPThread);
        }
        g_secondaryMachThread = 0;
        g_secondaryPThread = 0;
    }

    g_exceptionPort = MACH_PORT_NULL;
    TTSDKLOG_DEBUG("Mach exception handlers uninstalled.");
}

static bool installExceptionHandler(void)
{
    TTSDKLOG_DEBUG("Installing mach exception handler.");

    bool attributes_created = false;
    pthread_attr_t attr;

    kern_return_t kr;
    int error;

    const task_t thisTask = mach_task_self();
    exception_mask_t mask =
        EXC_MASK_BAD_ACCESS | EXC_MASK_BAD_INSTRUCTION | EXC_MASK_ARITHMETIC | EXC_MASK_SOFTWARE | EXC_MASK_BREAKPOINT;

    TTSDKLOG_DEBUG("Backing up original exception ports.");
    kr = task_get_exception_ports(thisTask, mask, g_previousExceptionPorts.masks, &g_previousExceptionPorts.count,
                                  g_previousExceptionPorts.ports, g_previousExceptionPorts.behaviors,
                                  g_previousExceptionPorts.flavors);
    if (kr != KERN_SUCCESS) {
        TTSDKLOG_ERROR("task_get_exception_ports: %s", mach_error_string(kr));
        goto failed;
    }

    if (g_exceptionPort == MACH_PORT_NULL) {
        TTSDKLOG_DEBUG("Allocating new port with receive rights.");
        kr = mach_port_allocate(thisTask, MACH_PORT_RIGHT_RECEIVE, &g_exceptionPort);
        if (kr != KERN_SUCCESS) {
            TTSDKLOG_ERROR("mach_port_allocate: %s", mach_error_string(kr));
            goto failed;
        }

        TTSDKLOG_DEBUG("Adding send rights to port.");
        kr = mach_port_insert_right(thisTask, g_exceptionPort, g_exceptionPort, MACH_MSG_TYPE_MAKE_SEND);
        if (kr != KERN_SUCCESS) {
            TTSDKLOG_ERROR("mach_port_insert_right: %s", mach_error_string(kr));
            goto failed;
        }
    }

    TTSDKLOG_DEBUG("Installing port as exception handler.");
    kr = task_set_exception_ports(thisTask, mask, g_exceptionPort, (int)(EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES),
                                  THREAD_STATE_NONE);
    if (kr != KERN_SUCCESS) {
        TTSDKLOG_ERROR("task_set_exception_ports: %s", mach_error_string(kr));
        goto failed;
    }

    TTSDKLOG_DEBUG("Creating secondary exception thread (suspended).");
    pthread_attr_init(&attr);
    attributes_created = true;
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    error = pthread_create(&g_secondaryPThread, &attr, &handleExceptions, (void *)kThreadSecondary);
    if (error != 0) {
        TTSDKLOG_ERROR("pthread_create_suspended_np: %s", strerror(error));
        goto failed;
    }
    g_secondaryMachThread = pthread_mach_thread_np(g_secondaryPThread);
    ttsdkmc_addReservedThread(g_secondaryMachThread);

    TTSDKLOG_DEBUG("Creating primary exception thread.");
    error = pthread_create(&g_primaryPThread, &attr, &handleExceptions, (void *)kThreadPrimary);
    if (error != 0) {
        TTSDKLOG_ERROR("pthread_create: %s", strerror(error));
        goto failed;
    }
    pthread_attr_destroy(&attr);
    g_primaryMachThread = pthread_mach_thread_np(g_primaryPThread);
    ttsdkmc_addReservedThread(g_primaryMachThread);

    TTSDKLOG_DEBUG("Mach exception handler installed.");
    return true;

failed:
    TTSDKLOG_DEBUG("Failed to install mach exception handler.");
    if (attributes_created) {
        pthread_attr_destroy(&attr);
    }
    uninstallExceptionHandler();
    return false;
}

static const char *monitorId(void) { return "MachException"; }

static TTSDKCrashMonitorFlag monitorFlags(void)
{
    return TTSDKCrashMonitorFlagFatal | TTSDKCrashMonitorFlagAsyncSafe | TTSDKCrashMonitorFlagDebuggerUnsafe;
}

static void setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
        if (isEnabled) {
            ttsdkid_generate(g_primaryEventID);
            ttsdkid_generate(g_secondaryEventID);
            if (!installExceptionHandler()) {
                return;
            }
        } else {
            uninstallExceptionHandler();
        }
    }
}

static bool isEnabled(void) { return g_isEnabled; }

static void addContextualInfoToEvent(struct TTSDKCrash_MonitorContext *eventContext)
{
    const char *signalName = ttsdkcm_getMonitorId(ttsdkcm_signal_getAPI());

    if (signalName && strcmp(eventContext->monitorId, signalName) == 0) {
        eventContext->mach.type = machExceptionForSignal(eventContext->signal.signum);
    } else if (strcmp(eventContext->monitorId, monitorId()) != 0) {
        eventContext->mach.type = EXC_CRASH;
    }
}

#endif

TTSDKCrashMonitorAPI *ttsdkcm_machexception_getAPI(void)
{
#if TTSDKCRASH_HAS_MACH
    static TTSDKCrashMonitorAPI api = {

        .monitorId = monitorId,
        .monitorFlags = monitorFlags,
        .setEnabled = setEnabled,
        .isEnabled = isEnabled,
        .addContextualInfoToEvent = addContextualInfoToEvent
    };
    return &api;
#else
    return NULL;
#endif
}
