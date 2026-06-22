//
//  TTSDKMachineContext.c
//
//  Created by Karl Stenerud on 2016-12-02.
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

#include "TTSDKMachineContext.h"

#include <mach/mach.h>

#if __has_include(<sys/_types/_ucontext64.h>)
#include <sys/_types/_ucontext64.h>
#endif

#include "TTSDKCPU.h"
#include "TTSDKCPU_Apple.h"
#include "TTSDKMachineContext_Apple.h"
#include "TTSDKStackCursor_MachineContext.h"
#include "TTSDKSystemCapabilities.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

#ifdef __arm64__
#if !(TTSDKCRASH_HOST_MAC)
#define _TTSDKCRASH_CONTEXT_64
#endif
#endif

#ifdef _TTSDKCRASH_CONTEXT_64
#define UC_MCONTEXT uc_mcontext64
typedef ucontext64_t SignalUserContext;
#undef _TTSDKCRASH_CONTEXT_64
#else
#define UC_MCONTEXT uc_mcontext
typedef ucontext_t SignalUserContext;
#endif

static TTSDKThread g_reservedThreads[10];
static int g_reservedThreadsMaxIndex = sizeof(g_reservedThreads) / sizeof(g_reservedThreads[0]) - 1;
static int g_reservedThreadsCount = 0;

static inline bool isStackOverflow(const TTSDKMachineContext *const context)
{
    TTSDKStackCursor stackCursor;
    ttsdttsdkc_initWithMachineContext(&stackCursor, TTSDKSC_STACK_OVERFLOW_THRESHOLD, context);
    while (stackCursor.advanceCursor(&stackCursor)) {
    }
    return stackCursor.state.hasGivenUp;
}

static inline bool getThreadList(TTSDKMachineContext *context)
{
    const task_t thisTask = mach_task_self();
    TTSDKLOG_DEBUG("Getting thread list");
    kern_return_t kr;
    thread_act_array_t threads;
    mach_msg_type_number_t actualThreadCount;

    if ((kr = task_threads(thisTask, &threads, &actualThreadCount)) != KERN_SUCCESS) {
        TTSDKLOG_ERROR("task_threads: %s", mach_error_string(kr));
        return false;
    }
    TTSDKLOG_TRACE("Got %d threads", context->threadCount);
    int threadCount = (int)actualThreadCount;
    int maxThreadCount = sizeof(context->allThreads) / sizeof(context->allThreads[0]);
    if (threadCount > maxThreadCount) {
        TTSDKLOG_ERROR("Thread count %d is higher than maximum of %d", threadCount, maxThreadCount);
        threadCount = maxThreadCount;
    }
    for (int i = 0; i < threadCount; i++) {
        context->allThreads[i] = threads[i];
    }
    context->threadCount = threadCount;

    for (mach_msg_type_number_t i = 0; i < actualThreadCount; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * actualThreadCount);

    return true;
}

int ttsdkmc_contextSize(void) { return sizeof(TTSDKMachineContext); }

TTSDKThread ttsdkmc_getThreadFromContext(const TTSDKMachineContext *const context) { return context->thisThread; }

bool ttsdkmc_getContextForThread(TTSDKThread thread, TTSDKMachineContext *destinationContext, bool isCrashedContext)
{
    TTSDKLOG_DEBUG("Fill thread 0x%x context into %p. is crashed = %d", thread, destinationContext, isCrashedContext);
    memset(destinationContext, 0, sizeof(*destinationContext));
    destinationContext->thisThread = (thread_t)thread;
    destinationContext->isCurrentThread = thread == ttsdkthread_self();
    destinationContext->isCrashedContext = isCrashedContext;
    destinationContext->isSignalContext = false;
    if (ttsdkmc_canHaveCPUState(destinationContext)) {
        ttsdkcpu_getState(destinationContext);
    }
    if (ttsdkmc_isCrashedContext(destinationContext)) {
        destinationContext->isStackOverflow = isStackOverflow(destinationContext);
        getThreadList(destinationContext);
    }
    TTSDKLOG_TRACE("Context retrieved.");
    return true;
}

bool ttsdkmc_getContextForSignal(void *signalUserContext, TTSDKMachineContext *destinationContext)
{
    TTSDKLOG_DEBUG("Get context from signal user context and put into %p.", destinationContext);
    _STRUCT_MCONTEXT *sourceContext = ((SignalUserContext *)signalUserContext)->UC_MCONTEXT;
    memcpy(&destinationContext->machineContext, sourceContext, sizeof(destinationContext->machineContext));
    destinationContext->thisThread = (thread_t)ttsdkthread_self();
    destinationContext->isCrashedContext = true;
    destinationContext->isSignalContext = true;
    destinationContext->isStackOverflow = isStackOverflow(destinationContext);
    getThreadList(destinationContext);
    TTSDKLOG_TRACE("Context retrieved.");
    return true;
}

void ttsdkmc_addReservedThread(TTSDKThread thread)
{
    int nextIndex = g_reservedThreadsCount;
    if (nextIndex > g_reservedThreadsMaxIndex) {
        TTSDKLOG_ERROR("Too many reserved threads (%d). Max is %d", nextIndex, g_reservedThreadsMaxIndex);
        return;
    }
    g_reservedThreads[g_reservedThreadsCount++] = thread;
}

#if TTSDKCRASH_HAS_THREADS_API
static inline bool isThreadInList(thread_t thread, TTSDKThread *list, int listCount)
{
    for (int i = 0; i < listCount; i++) {
        if (list[i] == (TTSDKThread)thread) {
            return true;
        }
    }
    return false;
}
#endif

void ttsdkmc_suspendEnvironment(__unused thread_act_array_t *suspendedThreads,
                             __unused mach_msg_type_number_t *numSuspendedThreads)
{
#if TTSDKCRASH_HAS_THREADS_API
    TTSDKLOG_DEBUG("Suspending environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ttsdkthread_self();

    if ((kr = task_threads(thisTask, suspendedThreads, numSuspendedThreads)) != KERN_SUCCESS) {
        TTSDKLOG_ERROR("task_threads: %s", mach_error_string(kr));
        return;
    }

    for (mach_msg_type_number_t i = 0; i < *numSuspendedThreads; i++) {
        thread_t thread = (*suspendedThreads)[i];
        if (thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount)) {
            if ((kr = thread_suspend(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                TTSDKLOG_ERROR("thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    TTSDKLOG_DEBUG("Suspend complete.");
#endif
}

void ttsdkmc_resumeEnvironment(__unused thread_act_array_t threads, __unused mach_msg_type_number_t numThreads)
{
#if TTSDKCRASH_HAS_THREADS_API
    TTSDKLOG_DEBUG("Resuming environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = (thread_t)ttsdkthread_self();

    if (threads == NULL || numThreads == 0) {
        TTSDKLOG_ERROR("we should call ttsdkmc_suspendEnvironment() first");
        return;
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        thread_t thread = threads[i];
        if (thread != thisThread && !isThreadInList(thread, g_reservedThreads, g_reservedThreadsCount)) {
            if ((kr = thread_resume(thread)) != KERN_SUCCESS) {
                // Record the error and keep going.
                TTSDKLOG_ERROR("thread_resume (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }

    for (mach_msg_type_number_t i = 0; i < numThreads; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);

    TTSDKLOG_DEBUG("Resume complete.");
#endif
}

int ttsdkmc_getThreadCount(const TTSDKMachineContext *const context) { return context->threadCount; }

TTSDKThread ttsdkmc_getThreadAtIndex(const TTSDKMachineContext *const context, int index) { return context->allThreads[index]; }

int ttsdkmc_indexOfThread(const TTSDKMachineContext *const context, TTSDKThread thread)
{
    TTSDKLOG_TRACE("check thread vs %d threads", context->threadCount);
    for (int i = 0; i < (int)context->threadCount; i++) {
        TTSDKLOG_TRACE("%d: %x vs %x", i, thread, context->allThreads[i]);
        if (context->allThreads[i] == thread) {
            return i;
        }
    }
    return -1;
}

bool ttsdkmc_isCrashedContext(const TTSDKMachineContext *const context) { return context->isCrashedContext; }

static inline bool isContextForCurrentThread(const TTSDKMachineContext *const context) { return context->isCurrentThread; }

static inline bool isSignalContext(const TTSDKMachineContext *const context) { return context->isSignalContext; }

bool ttsdkmc_canHaveCPUState(const TTSDKMachineContext *const context)
{
    return !isContextForCurrentThread(context) || isSignalContext(context);
}

bool ttsdkmc_hasValidExceptionRegisters(const TTSDKMachineContext *const context)
{
    return ttsdkmc_canHaveCPUState(context) && ttsdkmc_isCrashedContext(context);
}
