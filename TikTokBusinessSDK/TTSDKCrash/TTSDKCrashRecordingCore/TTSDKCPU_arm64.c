//
//  TTSDKCPU_arm64_Apple.c
//
//  Created by Karl Stenerud on 2013-09-29.
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

#if defined(__arm64__)

#include <stdlib.h>

#include "TTSDKCPU.h"
#include "TTSDKCPU_Apple.h"
#include "TTSDKMachineContext.h"
#include "TTSDKMachineContext_Apple.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

#define TTSDKPACStrippingMask_ARM64e 0x0000000fffffffff

static const char *g_registerNames[] = { "x0",  "x1",  "x2",  "x3",  "x4",  "x5",  "x6",  "x7",  "x8",
                                         "x9",  "x10", "x11", "x12", "x13", "x14", "x15", "x16", "x17",
                                         "x18", "x19", "x20", "x21", "x22", "x23", "x24", "x25", "x26",
                                         "x27", "x28", "x29", "fp",  "lr",  "sp",  "pc",  "cpsr" };
static const int g_registerNamesCount = sizeof(g_registerNames) / sizeof(*g_registerNames);

static const char *g_exceptionRegisterNames[] = { "exception", "esr", "far" };
static const int g_exceptionRegisterNamesCount = sizeof(g_exceptionRegisterNames) / sizeof(*g_exceptionRegisterNames);

uintptr_t ttsdkcpu_framePointer(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__fp; }

uintptr_t ttsdkcpu_stackPointer(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__sp; }

uintptr_t ttsdkcpu_instructionAddress(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__pc; }

uintptr_t ttsdkcpu_linkRegister(const TTSDKMachineContext *const context) { return context->machineContext.__ss.__lr; }

void ttsdkcpu_getState(TTSDKMachineContext *context)
{
    thread_t thread = context->thisThread;
    STRUCT_MCONTEXT_L *const machineContext = &context->machineContext;

    ttsdkcpu_i_fillState(thread, (thread_state_t)&machineContext->__ss, ARM_THREAD_STATE64, ARM_THREAD_STATE64_COUNT);
    ttsdkcpu_i_fillState(thread, (thread_state_t)&machineContext->__es, ARM_EXCEPTION_STATE64,
                      ARM_EXCEPTION_STATE64_COUNT);
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
    if (regNumber <= 29) {
        return context->machineContext.__ss.__x[regNumber];
    }

    switch (regNumber) {
        case 30:
            return context->machineContext.__ss.__fp;
        case 31:
            return context->machineContext.__ss.__lr;
        case 32:
            return context->machineContext.__ss.__sp;
        case 33:
            return context->machineContext.__ss.__pc;
        case 34:
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
            return context->machineContext.__es.__esr;
        case 2:
            return context->machineContext.__es.__far;
    }

    TTSDKLOG_ERROR("Invalid register number: %d", regNumber);
    return 0;
}

uintptr_t ttsdkcpu_faultAddress(const TTSDKMachineContext *const context) { return context->machineContext.__es.__far; }

int ttsdkcpu_stackGrowDirection(void) { return -1; }

uintptr_t ttsdkcpu_normaliseInstructionPointer(uintptr_t ip) { return ip & TTSDKPACStrippingMask_ARM64e; }

#endif
