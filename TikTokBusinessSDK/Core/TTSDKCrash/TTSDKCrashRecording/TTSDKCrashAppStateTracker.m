//
//  TTSDKCrashAppStateTracker.m
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
#import "TTSDKCrashAppStateTracker.h"

#import "TTSDKSystemCapabilities.h"

#import <Foundation/Foundation.h>
#import <os/lock.h>

#if TTSDKCRASH_HAS_UIAPPLICATION
#import <UIKit/UIKit.h>
#endif

const char *ttsdkapp_transitionStateToString(TTSDKCrashAppTransitionState state)
{
    switch (state) {
        case TTSDKCrashAppTransitionStateStartup:
            return "startup";
        case TTSDKCrashAppTransitionStateStartupPrewarm:
            return "prewarm";
        case TTSDKCrashAppTransitionStateActive:
            return "active";
        case TTSDKCrashAppTransitionStateLaunching:
            return "launching";
        case TTSDKCrashAppTransitionStateBackground:
            return "background";
        case TTSDKCrashAppTransitionStateTerminating:
            return "terminating";
        case TTSDKCrashAppTransitionStateExiting:
            return "exiting";
        case TTSDKCrashAppTransitionStateDeactivating:
            return "deactivating";
        case TTSDKCrashAppTransitionStateForegrounding:
            return "foregrounding";
    }
    return "unknown";
}

bool ttsdkapp_transitionStateIsUserPerceptible(TTSDKCrashAppTransitionState state)
{
    switch (state) {
        case TTSDKCrashAppTransitionStateStartupPrewarm:
        case TTSDKCrashAppTransitionStateBackground:
        case TTSDKCrashAppTransitionStateTerminating:
        case TTSDKCrashAppTransitionStateExiting:
            return NO;

        case TTSDKCrashAppTransitionStateStartup:
        case TTSDKCrashAppTransitionStateLaunching:
        case TTSDKCrashAppTransitionStateForegrounding:
        case TTSDKCrashAppTransitionStateActive:
        case TTSDKCrashAppTransitionStateDeactivating:
            return YES;
    }
    return NO;
}

@interface TTSDKCrashAppStateTrackerBlockObserver : NSObject <TTSDKCrashAppStateTrackerObserving>

@property(nonatomic, copy) TTSDKCrashAppStateTrackerObserverBlock block;
@property(nonatomic, weak) id<TTSDKCrashAppStateTrackerObserving> object;

@property(nonatomic, weak) TTSDKCrashAppStateTracker *tracker;

- (BOOL)shouldReap;

@end

@implementation TTSDKCrashAppStateTrackerBlockObserver

- (void)appStateTracker:(nonnull TTSDKCrashAppStateTracker *)tracker
    didTransitionToState:(TTSDKCrashAppTransitionState)transitionState
{
    TTSDKCrashAppStateTrackerObserverBlock block = self.block;
    if (block) {
        block(transitionState);
    }

    id<TTSDKCrashAppStateTrackerObserving> object = self.object;
    if (object) {
        [object appStateTracker:self.tracker didTransitionToState:transitionState];
    }
}

- (BOOL)shouldReap
{
    return self.block == nil && self.object == nil;
}

@end

@interface TTSDKCrashAppStateTracker () {
    NSNotificationCenter *_center;
    NSArray<id<NSObject>> *_registrations;

    // transition state and observers protected by the lock
    os_unfair_lock _lock;
    TTSDKCrashAppTransitionState _transitionState;
    NSMutableArray<id<TTSDKCrashAppStateTrackerObserving>> *_observers;
}
@end

@implementation TTSDKCrashAppStateTracker

+ (void)load
{
    // to work well, we need this to run as early as possible.
    (void)[TTSDKCrashAppStateTracker sharedInstance];
}

+ (instancetype)sharedInstance
{
    static TTSDKCrashAppStateTracker *sTracker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sTracker = [[TTSDKCrashAppStateTracker alloc] init];
        [sTracker start];
    });
    return sTracker;
}

- (instancetype)init
{
    return [self initWithNotificationCenter:NSNotificationCenter.defaultCenter];
}

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter
{
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _observers = [NSMutableArray array];
        _center = notificationCenter;
        _registrations = nil;

        BOOL isPrewarm = [NSProcessInfo.processInfo.environment[@"ActivePrewarm"] boolValue];
        _transitionState = isPrewarm ? TTSDKCrashAppTransitionStateStartupPrewarm : TTSDKCrashAppTransitionStateStartup;
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

// Observers are either an object passed in that
// implements `TTSDKCrashAppStateTrackerObserving` or a block.
// Both will be wrapped in a `TTSDKCrashAppStateTrackerBlockObserver`.
// if a block, then it'll simply call the block.
// If the object, we'll keep a weak reference to it.
// Objects will be reaped when their block and their object
// is nil.
// We'll reap on add and removal or any type of observer.
- (void)_locked_reapObserversOrObject:(id)object
{
    NSMutableArray *toRemove = [NSMutableArray array];
    for (TTSDKCrashAppStateTrackerBlockObserver *obj in _observers) {
        if ((obj.object != nil && obj.object == object) || [obj shouldReap]) {
            [toRemove addObject:obj];
            obj.object = nil;
            obj.block = nil;
        }
    }
    [_observers removeObjectsInArray:toRemove];
}

- (void)_addObserver:(TTSDKCrashAppStateTrackerBlockObserver *)observer
{
    os_unfair_lock_lock(&_lock);
    [_observers addObject:observer];
    [self _locked_reapObserversOrObject:nil];
    os_unfair_lock_unlock(&_lock);
}

- (void)addObserver:(id<TTSDKCrashAppStateTrackerObserving>)observer
{
    TTSDKCrashAppStateTrackerBlockObserver *obs = [[TTSDKCrashAppStateTrackerBlockObserver alloc] init];
    obs.object = observer;
    obs.tracker = self;
    [self _addObserver:obs];
}

- (id<TTSDKCrashAppStateTrackerObserving>)addObserverWithBlock:(TTSDKCrashAppStateTrackerObserverBlock)block
{
    TTSDKCrashAppStateTrackerBlockObserver *obs = [[TTSDKCrashAppStateTrackerBlockObserver alloc] init];
    obs.block = [block copy];
    obs.tracker = self;
    [self _addObserver:obs];
    return obs;
}

- (void)removeObserver:(id<TTSDKCrashAppStateTrackerObserving>)observer
{
    os_unfair_lock_lock(&_lock);

    // Observers added with a block
    if ([observer isKindOfClass:TTSDKCrashAppStateTrackerBlockObserver.class]) {
        TTSDKCrashAppStateTrackerBlockObserver *obs = (TTSDKCrashAppStateTrackerBlockObserver *)observer;
        obs.block = nil;
        obs.object = nil;
        [self _locked_reapObserversOrObject:nil];
    }

    // observers added with an object
    else {
        [self _locked_reapObserversOrObject:observer];
    }

    os_unfair_lock_unlock(&_lock);
}

- (TTSDKCrashAppTransitionState)transitionState
{
    TTSDKCrashAppTransitionState ret;
    {
        os_unfair_lock_lock(&_lock);
        ret = _transitionState;
        os_unfair_lock_unlock(&_lock);
    }
    return ret;
}

- (void)_setTransitionState:(TTSDKCrashAppTransitionState)transitionState
{
    NSArray<id<TTSDKCrashAppStateTrackerObserving>> *observers = nil;
    {
        os_unfair_lock_lock(&_lock);
        if (_transitionState != transitionState) {
            _transitionState = transitionState;
            observers = [_observers copy];
        }
        os_unfair_lock_unlock(&_lock);
    }

    for (id<TTSDKCrashAppStateTrackerObserving> obs in observers) {
        [obs appStateTracker:self didTransitionToState:transitionState];
    }
}

#define OBSERVE(center, name, block) \
    [center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification * notification) block]

- (void)_exitCalled
{
    // _registrations is nil when the system is stopped
    if (!_registrations) {
        return;
    }
    [self _setTransitionState:TTSDKCrashAppTransitionStateExiting];
}

- (void)start
{
    if (_registrations) {
        return;
    }

    __weak typeof(self) weakMe = self;

    // Register a normal `exit` callback so we don't think it's an OOM.
    atexit_b(^{
        [weakMe _exitCalled];
    });

#if TTSDKCRASH_HAS_UIAPPLICATION

    // register all normal lifecycle events
    // in the future, we could also look at scene lifecycle
    // events but in reality, we don't actually need to,
    // it could just give us more granularity.
    _registrations = @[

        OBSERVE(_center, UIApplicationDidFinishLaunchingNotification,
                { [weakMe _setTransitionState:TTSDKCrashAppTransitionStateLaunching]; }),
        OBSERVE(_center, UIApplicationWillEnterForegroundNotification,
                { [weakMe _setTransitionState:TTSDKCrashAppTransitionStateForegrounding]; }),
        OBSERVE(_center, UIApplicationDidBecomeActiveNotification,
                { [weakMe _setTransitionState:TTSDKCrashAppTransitionStateActive]; }),
        OBSERVE(_center, UIApplicationWillResignActiveNotification,
                { [weakMe _setTransitionState:TTSDKCrashAppTransitionStateDeactivating]; }),
        OBSERVE(_center, UIApplicationDidEnterBackgroundNotification,
                { [weakMe _setTransitionState:TTSDKCrashAppTransitionStateBackground]; }),
        OBSERVE(_center, UIApplicationWillTerminateNotification,
                { [weakMe _setTransitionState:TTSDKCrashAppTransitionStateTerminating]; }),
    ];

#else
    // on other platforms that don't have UIApplication
    // we simply state that the app is active in order to report OOMs.
    [self _setTransitionState:TTSDKCrashAppTransitionStateActive];
#endif
}

- (void)stop
{
    NSArray<id<NSObject>> *registraions = [_registrations copy];
    _registrations = nil;
    for (id<NSObject> registraion in registraions) {
        [_center removeObserver:registraion];
    }
}

@end
