//
//  TTSDKStackCursor.h
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
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

#include "TTSDKStackCursor.h"

#include <stdlib.h>

#include "TTSDKSymbolicator.h"

// #define TTSDKLogger_LocalLevel TRACE
#include "TTSDKLogger.h"

static bool g_advanceCursor(__unused TTSDKStackCursor *cursor)
{
    TTSDKLOG_WARN(
        "No stack cursor has been set. For C++, this means that hooking __cxa_throw() failed for some reason. Embedded "
        "frameworks can cause this: https://github.com/kstenerud/TTSDKCrash/issues/205");
    return false;
}

void ttsdttsdkc_resetCursor(TTSDKStackCursor *cursor)
{
    cursor->state.currentDepth = 0;
    cursor->state.hasGivenUp = false;
    cursor->stackEntry.address = 0;
    cursor->stackEntry.imageAddress = 0;
    cursor->stackEntry.imageName = NULL;
    cursor->stackEntry.symbolAddress = 0;
    cursor->stackEntry.symbolName = NULL;
}

void ttsdttsdkc_initCursor(TTSDKStackCursor *cursor, void (*resetCursor)(TTSDKStackCursor *),
                     bool (*advanceCursor)(TTSDKStackCursor *))
{
    cursor->symbolicate = ttsdksymbolicator_symbolicate;
    cursor->advanceCursor = advanceCursor != NULL ? advanceCursor : g_advanceCursor;
    cursor->resetCursor = resetCursor != NULL ? resetCursor : ttsdttsdkc_resetCursor;
    cursor->resetCursor(cursor);
}
