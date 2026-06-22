//
//  TTSDKCrashAppTransitionState.h
//
//  Created by Alexander Cohen on 2024-05-20.
//
//  Copyright (c) 2024 Alexander Cohen. All rights reserved.
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
#ifndef TTSDKCrashAppTransitionState_h
#define TTSDKCrashAppTransitionState_h

#include <stdbool.h>
#include <stdint.h>
#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME(_name)
#endif

// clang-format off
/** States of transition for the application */
#ifdef __OBJC__
typedef NS_ENUM(uint8_t, TTSDKCrashAppTransitionState)
#else
enum
#endif
{
    TTSDKCrashAppTransitionStateStartup = 0,
    TTSDKCrashAppTransitionStateStartupPrewarm,
    TTSDKCrashAppTransitionStateLaunching,
    TTSDKCrashAppTransitionStateForegrounding,
    TTSDKCrashAppTransitionStateActive,
    TTSDKCrashAppTransitionStateDeactivating,
    TTSDKCrashAppTransitionStateBackground,
    TTSDKCrashAppTransitionStateTerminating,
    TTSDKCrashAppTransitionStateExiting,
} NS_SWIFT_NAME(AppTransitionState);
#ifndef __OBJC__
typedef uint8_t TTSDKCrashAppTransitionState;
#endif
// clang-format on

/**
 * Returns true if the transition state is user perceptible.
 */
bool ttsdkapp_transitionStateIsUserPerceptible(TTSDKCrashAppTransitionState state)
    NS_SWIFT_NAME(AppTransitionState.isUserPerceptible(self:));

/**
 * Returns a string for the app state passed in.
 */
const char *ttsdkapp_transitionStateToString(TTSDKCrashAppTransitionState state)
    NS_SWIFT_NAME(AppTransitionState.cString(self:));

#ifdef __cplusplus
}
#endif

#endif /* TTSDKCrashAppTransitionState_h */
