//
//  TTSDKCPU_arm.c
//
//  Created by Karl Stenerud on 2012-01-29.
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

#if defined(__arm__)

#include <stdlib.h>

#include "TTSDKCPU.h"
#include "TTSDKCPU_Apple.h"
#include "TTSDKMachineContext.h"
#include "TTSDKMachineContext_Apple.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

static const char *g_registerNames[] = { "r0", "r1",  "r2",  "r3", "r4", "r5", "r6", "r7",  "r8",
                                         "r9", "r10", "r11", "ip", "sp", "lr", "pc", "cpsr" };
static const int g_registerNamesCount = sizeof(g_registerNames) / sizeof(*g_registerNames);

static const char *g_exceptionRegisterNames[] = { "exception", "fsr", "far" };
static const int g_exceptionRegisterNamesCount = sizeof(g_exceptionRegisterNames) / sizeof(*g_exceptionRegisterNames);

uintptr_t ttsdkcpu_framePointer(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__r[7]; }

uintptr_t ttsdkcpu_stackPointer(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__sp; }

uintptr_t ttsdkcpu_instructionAddress(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__pc; }

uintptr_t ttsdkcpu_linkRegister(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__lr; }

void ttsdkcpu_getState(TTSDKMachineContext *context)
{
    thread_t thread = context->thisThread;
    STRUCT_MCONTEXT_L *const machineContext = &context->machineContext;

    ttsdkcpu_i_fillState(thread, (thread_state_t)&machineContext->__ss, ARM_THREAD_STATE, ARM_THREAD_STATE_COUNT);
    ttsdkcpu_i_fillState(thread, (thread_state_t)&machineContext->__es, ARM_EXCEPTION_STATE, ARM_EXCEPTION_STATE_COUNT);
}

int ttsdkcpu_numRegisters(void) { return g_registerNamesCount; }

const char *ttsdkcpu_registerName(const int regNumber)
{
    if (regNumber < ttsdkcpu_numRegisters()) {
        return g_registerNames[regNumber];
    }
    return NULL;
}

uint64_t ttsdkcpu_registerValue(const TTSDKMachineContext *const context, const int regNumber)
{
    if (regNumber <= 12) {
        return context->machineContext.__ss.__r[regNumber];
    }

    switch (regNumber) {
        case 13:
            return context->machineContext.__ss.__sp;
        case 14:
            return context->machineContext.__ss.__lr;
        case 15:
            return context->machineContext.__ss.__pc;
        case 16:
            return context->machineContext.__ss.__cpsr;
    }

    TTSDKLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

int ttsdkcpu_numExceptionRegisters(void) { return g_exceptionRegisterNamesCount; }

const char *ttsdkcpu_exceptionRegisterName(const int regNumber)
{
    if (regNumber < ttsdkcpu_numExceptionRegisters()) {
        return g_exceptionRegisterNames[regNumber];
    }
    TTSDKLOG_ERROR("Invalid register number: %d", regNumber);
    return NULL;
}

uint64_t ttsdkcpu_exceptionRegisterValue(const TTSDKMachineContext *const context, const int regNumber)
{
    switch (regNumber) {
        case 0:
            return context->machineContext.__es.__exception;
        case 1:
            return context->machineContext.__es.__fsr;
        case 2:
            return context->machineContext.__es.__far;
    }

    TTSDKLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

uintptr_t ttsdkcpu_faultAddress(const TTSDKMachineContext *const context) { return context->machineContext.__es.__far; }

int ttsdkcpu_stackGrowDirection(void) { return -1; }

uintptr_t ttsdkcpu_normaliseInstructionPointer(uintptr_t ip) { return ip; }

#endif
