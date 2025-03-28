//
//  TTSDKCrashMonitor_DiscSpace.c
//
//  Created by Gleb Linnik on 04.06.2024.
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

#import "TTSDKCrashMonitor_DiscSpace.h"

#import "TTSDKCrashMonitorContext.h"

#import <Foundation/Foundation.h>

static volatile bool g_isEnabled = false;

__attribute__((unused)) // For tests. Declared as extern in TestCase
void ttsdkcm_discSpace_resetState(void)
{
    g_isEnabled = false;
}

static uint64_t getStorageSize(void)
{
    NSNumber *storageSize = [[[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil]
        objectForKey:NSFileSystemSize];
    return storageSize.unsignedLongLongValue;
}

#pragma mark - API -

static const char *monitorId(void) { return "DiscSpace"; }

static void setEnabled(bool isEnabled)
{
    if (isEnabled != g_isEnabled) {
        g_isEnabled = isEnabled;
    }
}

static bool isEnabled(void) { return g_isEnabled; }

static void addContextualInfoToEvent(TTSDKCrash_MonitorContext *eventContext)
{
    if (g_isEnabled) {
        eventContext->System.storageSize = getStorageSize();
    }
}

TTSDKCrashMonitorAPI *ttsdkcm_discspace_getAPI(void)
{
    static TTSDKCrashMonitorAPI api = { .monitorId = monitorId,
                                     .setEnabled = setEnabled,
                                     .isEnabled = isEnabled,
                                     .addContextualInfoToEvent = addContextualInfoToEvent };
    return &api;
}

#pragma mark - Injection -

__attribute__((constructor)) static void ttsdkcm_discspace_register(void) { ttsdkcm_addMonitor(ttsdkcm_discspace_getAPI()); }
