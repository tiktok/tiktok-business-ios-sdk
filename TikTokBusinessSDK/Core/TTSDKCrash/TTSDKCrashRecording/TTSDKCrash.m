//
//  TTSDKCrash.m
//
//  Created by Karl Stenerud on 2012-01-28.
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

#import "TTSDKCrash.h"
#import "TTSDKCrash+Private.h"

#import "TTSDKCrashC.h"
#import "TTSDKCrashConfiguration+Private.h"
#import "TTSDKCrashMonitorContext.h"
#import "TTSDKCrashMonitor_AppState.h"
#import "TTSDKCrashMonitor_Memory.h"
#import "TTSDKCrashMonitor_System.h"
#import "TTSDKCrashReport.h"
#import "TTSDKCrashReportFields.h"
#import "TTSDKJSONCodecObjC.h"
#import "TTSDKNSErrorHelper.h"
#import "TTSDKSystemCapabilities.h"

// #define TTSDKLogger_LocalLevel TRACE
#import "TTSDKLogger.h"

#include <inttypes.h>
#if TTSDKCRASH_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

// ============================================================================
#pragma mark - Globals -
// ============================================================================

@interface TTSDKCrash ()

@property(nonatomic, readwrite, copy) NSString *bundleName;
@property(nonatomic, strong) TTSDKCrashConfiguration *configuration;

@end

static BOOL gIsSharedInstanceCreated = NO;

NSString *ttsdkcrash_getBundleName(void)
{
    NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    if (bundleName == nil) {
        bundleName = @"Unknown";
    }
    return bundleName;
}

NSString *ttsdkcrash_getDefaultInstallPath(void)
{
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([directories count] == 0) {
        TTSDKLOG_ERROR(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *cachePath = [directories objectAtIndex:0];
    if ([cachePath length] == 0) {
        TTSDKLOG_ERROR(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *pathEnd = [@"TTSDKCrash" stringByAppendingPathComponent:ttsdkcrash_getBundleName()];
    return [cachePath stringByAppendingPathComponent:pathEnd];
}

@implementation TTSDKCrash

// ============================================================================
#pragma mark - Lifecycle -
// ============================================================================

+ (void)load
{
    [[self class] classDidBecomeLoaded];
}

+ (void)initialize
{
    if (self == [TTSDKCrash class]) {
        [[self class] subscribeToNotifications];
    }
}

+ (instancetype)sharedInstance
{
    static TTSDKCrash *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[TTSDKCrash alloc] init];
        gIsSharedInstanceCreated = YES;
    });
    return sharedInstance;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _bundleName = ttsdkcrash_getBundleName();
    }
    return self;
}

// ============================================================================
#pragma mark - API -
// ============================================================================

- (NSDictionary *)userInfo
{
    const char *userInfoJSON = ttsdkcrash_getUserInfoJSON();
    if (userInfoJSON != NULL && strlen(userInfoJSON) > 0) {
        NSError *error = nil;
        NSData *jsonData = [NSData dataWithBytes:userInfoJSON length:strlen(userInfoJSON)];
        NSDictionary *userInfoDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        free((void *)userInfoJSON);  // Free the allocated memory

        if (error != nil) {
            TTSDKLOG_ERROR(@"Error parsing JSON: %@", error.localizedDescription);
            return nil;
        }
        return userInfoDict;
    }
    return nil;
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    NSError *error = nil;
    NSData *userInfoJSON = nil;

    if (userInfo != nil) {
        userInfoJSON = [NSJSONSerialization dataWithJSONObject:userInfo options:NSJSONWritingSortedKeys error:&error];

        if (error != nil) {
            TTSDKLOG_ERROR(@"Could not serialize user info: %@", error.localizedDescription);
            return;
        }
    }

    const char *userInfoCString = userInfoJSON ? [userInfoJSON bytes] : NULL;
    ttsdkcrash_setUserInfoJSON(userInfoCString);
}

- (BOOL)reportsMemoryTerminations
{
    return ttsdkmemory_get_fatal_reports_enabled();
}

- (void)setReportsMemoryTerminations:(BOOL)reportsMemoryTerminations
{
    ttsdkmemory_set_fatal_reports_enabled(reportsMemoryTerminations);
}

- (NSDictionary *)systemInfo
{
    TTSDKCrash_MonitorContext fakeEvent = { 0 };
    ttsdkcm_system_getAPI()->addContextualInfoToEvent(&fakeEvent);
    NSMutableDictionary *dict = [NSMutableDictionary new];

#define COPY_STRING(A) \
    if (fakeEvent.System.A) dict[@ #A] = [NSString stringWithUTF8String:fakeEvent.System.A]
#define COPY_PRIMITIVE(A) dict[@ #A] = @(fakeEvent.System.A)
    COPY_STRING(systemName);
    COPY_STRING(systemVersion);
    COPY_STRING(machine);
    COPY_STRING(model);
    COPY_STRING(kernelVersion);
    COPY_STRING(osVersion);
    COPY_PRIMITIVE(isJailbroken);
    COPY_STRING(bootTime);  // this field is populated in an optional monitor
    COPY_STRING(appStartTime);
    COPY_STRING(executablePath);
    COPY_STRING(executableName);
    COPY_STRING(bundleID);
    COPY_STRING(bundleName);
    COPY_STRING(bundleVersion);
    COPY_STRING(bundleShortVersion);
    COPY_STRING(appID);
    COPY_STRING(cpuArchitecture);
    COPY_PRIMITIVE(cpuType);
    COPY_PRIMITIVE(cpuSubType);
    COPY_PRIMITIVE(binaryCPUType);
    COPY_PRIMITIVE(binaryCPUSubType);
    COPY_STRING(timezone);
    COPY_STRING(processName);
    COPY_PRIMITIVE(processID);
    COPY_PRIMITIVE(parentProcessID);
    COPY_STRING(deviceAppHash);
    COPY_STRING(buildType);
    COPY_PRIMITIVE(storageSize);  // this field is populated in an optional monitor
    COPY_PRIMITIVE(memorySize);
    COPY_PRIMITIVE(freeMemory);
    COPY_PRIMITIVE(usableMemory);

    return [dict copy];
}

- (BOOL)installWithConfiguration:(TTSDKCrashConfiguration *)configuration error:(NSError **)error
{
    self.configuration = [configuration copy] ?: [TTSDKCrashConfiguration new];
    self.configuration.installPath = configuration.installPath ?: ttsdkcrash_getDefaultInstallPath();

    if (self.configuration.reportStoreConfiguration.appName == nil) {
        self.configuration.reportStoreConfiguration.appName = self.bundleName;
    }
    if (self.configuration.reportStoreConfiguration.reportsPath == nil) {
        self.configuration.reportStoreConfiguration.reportsPath = [self.configuration.installPath
            stringByAppendingPathComponent:[TTSDKCrashReportStore defaultInstallSubfolder]];
    }
    TTSDKCrashReportStore *reportStore =
        [TTSDKCrashReportStore storeWithConfiguration:self.configuration.reportStoreConfiguration error:error];
    if (reportStore == nil) {
        return NO;
    }

    TTSDKCrashCConfiguration config = [self.configuration toCConfiguration];
    TTSDKCrashInstallErrorCode result =
        ttsdkcrash_install(self.bundleName.UTF8String, self.configuration.installPath.UTF8String, &config);
    TTSDKCrashCConfiguration_Release(&config);
    if (result != TTSDKCrashInstallErrorNone) {
        if (error != NULL) {
            *error = [TTSDKCrash errorForInstallErrorCode:result];
        }
        return NO;
    }

    _reportStore = reportStore;
    return YES;
}

- (void)reportUserException:(NSString *)name
                     reason:(NSString *)reason
                   language:(NSString *)language
                 lineOfCode:(NSString *)lineOfCode
                 stackTrace:(NSArray *)stackTrace
              logAllThreads:(BOOL)logAllThreads
           terminateProgram:(BOOL)terminateProgram
{
    const char *cName = [name cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cReason = [reason cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cLanguage = [language cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cLineOfCode = [lineOfCode cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cStackTrace = NULL;

    if (stackTrace != nil) {
        NSError *error = nil;
        NSData *jsonData = [TTSDKJSONCodec encode:stackTrace options:0 error:&error];
        if (jsonData == nil || error != nil) {
            TTSDKLOG_ERROR(@"Error encoding stack trace to JSON: %@", error);
            // Don't return, since we can still record other useful information.
        }
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        cStackTrace = [jsonString cStringUsingEncoding:NSUTF8StringEncoding];
    }

    ttsdkcrash_reportUserException(cName, cReason, cLanguage, cLineOfCode, cStackTrace, logAllThreads, terminateProgram);
}

// ============================================================================
#pragma mark - Advanced API -
// ============================================================================

#define SYNTHESIZE_CRASH_STATE_PROPERTY(TYPE, NAME) \
    -(TYPE)NAME { return ttsdkcrashstate_currentState()->NAME; }

SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, backgroundDurationSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSInteger, launchesSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSInteger, sessionsSinceLastCrash)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, activeDurationSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSTimeInterval, backgroundDurationSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(NSInteger, sessionsSinceLaunch)
SYNTHESIZE_CRASH_STATE_PROPERTY(BOOL, crashedLastLaunch)

// ============================================================================
#pragma mark - Utility -
// ============================================================================

- (NSMutableData *)nullTerminated:(NSData *)data
{
    if (data == nil) {
        return NULL;
    }
    NSMutableData *mutable = [NSMutableData dataWithData:data];
    [mutable appendBytes:"\0" length:1];
    return mutable;
}

+ (NSError *)errorForInstallErrorCode:(TTSDKCrashInstallErrorCode)errorCode
{
    NSString *errorDescription;
    switch (errorCode) {
        case TTSDKCrashInstallErrorNone:
            return nil;
        case TTSDKCrashInstallErrorAlreadyInstalled:
            errorDescription = @"TTSDKCrash is already installed";
            break;
        case TTSDKCrashInstallErrorInvalidParameter:
            errorDescription = @"Invalid parameter provided";
            break;
        case TTSDKCrashInstallErrorPathTooLong:
            errorDescription = @"Path is too long";
            break;
        case TTSDKCrashInstallErrorCouldNotCreatePath:
            errorDescription = @"Could not create path";
            break;
        case TTSDKCrashInstallErrorCouldNotInitializeStore:
            errorDescription = @"Could not initialize crash report store";
            break;
        case TTSDKCrashInstallErrorCouldNotInitializeMemory:
            errorDescription = @"Could not initialize memory management";
            break;
        case TTSDKCrashInstallErrorCouldNotInitializeCrashState:
            errorDescription = @"Could not initialize crash state";
            break;
        case TTSDKCrashInstallErrorCouldNotSetLogFilename:
            errorDescription = @"Could not set log filename";
            break;
        case TTSDKCrashInstallErrorNoActiveMonitors:
            errorDescription = @"No crash monitors were activated";
            break;
        default:
            errorDescription = @"Unknown error occurred";
            break;
    }
    return [NSError errorWithDomain:TTSDKCrashErrorDomain
                               code:errorCode
                           userInfo:@{ NSLocalizedDescriptionKey : errorDescription }];
}

// ============================================================================
#pragma mark - Notifications -
// ============================================================================

+ (void)subscribeToNotifications
{
#if TTSDKCRASH_HAS_UIAPPLICATION
    NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:UIApplicationDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:UIApplicationWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:UIApplicationDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:UIApplicationWillEnterForegroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillTerminate)
                    name:UIApplicationWillTerminateNotification
                  object:nil];
#endif
#if TTSDKCRASH_HAS_NSEXTENSION
    NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self
                selector:@selector(applicationDidBecomeActive)
                    name:NSExtensionHostDidBecomeActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillResignActive)
                    name:NSExtensionHostWillResignActiveNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationDidEnterBackground)
                    name:NSExtensionHostDidEnterBackgroundNotification
                  object:nil];
    [nCenter addObserver:self
                selector:@selector(applicationWillEnterForeground)
                    name:NSExtensionHostWillEnterForegroundNotification
                  object:nil];
#endif
}

+ (void)classDidBecomeLoaded
{
    ttsdkcrash_notifyObjCLoad();
}

+ (void)applicationDidBecomeActive
{
    ttsdkcrash_notifyAppActive(true);
}

+ (void)applicationWillResignActive
{
    ttsdkcrash_notifyAppActive(false);
}

+ (void)applicationDidEnterBackground
{
    ttsdkcrash_notifyAppInForeground(false);
}

+ (void)applicationWillEnterForeground
{
    ttsdkcrash_notifyAppInForeground(true);
}

+ (void)applicationWillTerminate
{
    ttsdkcrash_notifyAppTerminate();
}

@end

//! Project version number for TTSDKCrashFramework.
const double TTSDKCrashFrameworkVersionNumber = 2.0000;

//! Project version string for TTSDKCrashFramework.
const unsigned char TTSDKCrashFrameworkVersionString[] = "2.0.0-rc.4";
