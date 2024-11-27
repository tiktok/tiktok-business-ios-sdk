//
//  TTSDKCrashMonitorHelper.h
//
//  Created by Gleb Linnik on 03.06.2024.
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

#ifndef TTSDKCrashMonitorHelper_h
#define TTSDKCrashMonitorHelper_h

#include "TTSDKCrashMonitor.h"

#ifdef __cplusplus
extern "C" {
#endif

static inline void ttsdkcm_setMonitorEnabled(const TTSDKCrashMonitorAPI *api, bool isEnabled)
{
    if (api != NULL && api->setEnabled != NULL) {
        api->setEnabled(isEnabled);
    }
}

static inline bool ttsdkcm_isMonitorEnabled(const TTSDKCrashMonitorAPI *api)
{
    if (api != NULL && api->isEnabled != NULL) {
        return api->isEnabled();
    }
    return false;
}

static inline const char *ttsdkcm_getMonitorId(const TTSDKCrashMonitorAPI *api)
{
    if (api != NULL && api->monitorId != NULL) {
        return api->monitorId();
    }
    return NULL;
}

static inline TTSDKCrashMonitorFlag ttsdkcm_getMonitorFlags(const TTSDKCrashMonitorAPI *api)
{
    if (api != NULL && api->monitorFlags != NULL) {
        return api->monitorFlags();
    }
    return TTSDKCrashMonitorFlagNone;
}

static inline void ttsdkcm_addContextualInfoToEvent(const TTSDKCrashMonitorAPI *api,
                                                 struct TTSDKCrash_MonitorContext *eventContext)
{
    if (api != NULL && api->addContextualInfoToEvent != NULL) {
        api->addContextualInfoToEvent(eventContext);
    }
}

static inline void ttsdkcm_notifyPostSystemEnable(const TTSDKCrashMonitorAPI *api)
{
    if (api != NULL && api->notifyPostSystemEnable != NULL) {
        api->notifyPostSystemEnable();
    }
}

#ifdef __cplusplus
}
#endif

#endif /* TTSDKCrashMonitorHelper_h */
