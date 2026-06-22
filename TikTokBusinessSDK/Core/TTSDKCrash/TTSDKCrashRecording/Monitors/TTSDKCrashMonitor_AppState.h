//
//  TTSDKCrashMonitor_AppState.h
//
//  Created by Karl Stenerud on 2012-02-05.
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

/* Manages persistent state information useful for crash reporting such as
 * number of sessions, session length, etc.
 */

#ifndef HDR_TTSDKCrashMonitor_AppState_h
#define HDR_TTSDKCrashMonitor_AppState_h

#include <stdbool.h>

#include "TTSDKCrashMonitor.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    // Saved data

    /** Total active time elapsed since the last crash. */
    double activeDurationSinceLastCrash;

    /** Total time backgrounded elapsed since the last crash. */
    double backgroundDurationSinceLastCrash;

    /** Number of app launches since the last crash. */
    int launchesSinceLastCrash;

    /** Number of sessions (launch, resume from suspend) since last crash. */
    int sessionsSinceLastCrash;

    /** Total active time elapsed since launch. */
    double activeDurationSinceLaunch;

    /** Total time backgrounded elapsed since launch. */
    double backgroundDurationSinceLaunch;

    /** Number of sessions (launch, resume from suspend) since app launch. */
    int sessionsSinceLaunch;

    /** If true, the application crashed on the previous launch. */
    bool crashedLastLaunch;

    // Live data

    /** If true, the application crashed on this launch. */
    bool crashedThisLaunch;

    /** Timestamp for when the app state was last changed (active<->inactive,
     * background<->foreground) */
    double appStateTransitionTime;

    /** If true, the application is currently active. */
    bool applicationIsActive;

    /** If true, the application is currently in the foreground. */
    bool applicationIsInForeground;

} TTSDKCrash_AppState;

/** Initialize the state monitor.
 *
 * @param stateFilePath Where to store on-disk representation of state.
 */
void ttsdkcrashstate_initialize(const char *stateFilePath);

/** Reset the crash state.
 */
bool ttsdkcrashstate_reset(void);

/** Notify the crash reporter of TTSDKCrash being added to Objective-C runtime system.
 */
void ttsdkcrashstate_notifyObjCLoad(void);

/** Notify the crash reporter of the application active state.
 *
 * @param isActive true if the application is active, otherwise false.
 */
void ttsdkcrashstate_notifyAppActive(bool isActive);

/** Notify the crash reporter of the application foreground/background state.
 *
 * @param isInForeground true if the application is in the foreground, false if
 *                 it is in the background.
 */
void ttsdkcrashstate_notifyAppInForeground(bool isInForeground);

/** Notify the crash reporter that the application is terminating.
 */
void ttsdkcrashstate_notifyAppTerminate(void);

/** Notify the crash reporter that the application has crashed.
 */
void ttsdkcrashstate_notifyAppCrash(void);

/** Read-only access into the current state.
 */
const TTSDKCrash_AppState *const ttsdkcrashstate_currentState(void);

/** Access the Monitor API.
 */
TTSDKCrashMonitorAPI *ttsdkcm_appstate_getAPI(void);

#ifdef __cplusplus
}
#endif

#endif  // HDR_TTSDKCrashMonitor_AppState_h
