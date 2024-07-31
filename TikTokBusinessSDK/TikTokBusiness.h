//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokConfig.h"
#import "TikTokLogger.h"
#import "TikTokBaseEvent.h"
#import "TikTokConstants.h"

NS_ASSUME_NONNULL_BEGIN

/** 
 * @brief This is the main interface for TikTok's Business SDK
 *
 * @note Use the methods exposed in this class to track app events
 *
*/
@interface TikTokBusiness : NSObject

@property (nonatomic) BOOL userTrackingEnabled;
@property (nonatomic) BOOL isRemoteSwitchOn;
@property (nonatomic) BOOL isGlobalConfigFetched;
@property (nonatomic) NSString *accessToken;
@property (nonatomic) NSString *anonymousID;
@property (nonatomic, assign, readonly) BOOL isDebugMode;

/**
 * @brief This method should be called in the didFinishLaunching method of your AppDelegate
 *        This is required to initialize the TikTokBusinessSDK
 *
 * @note See TikTokConfig.h for more configuration options
 *
 * @param tiktokConfig The configuration object must be initialized before this function is called.
 *                     This object contains the accessToken, appId and tiktokAppId which can be acquired from
 *                     TikTok's Marketing API dashboard.
*/
+ (void)initializeSdk: (nullable TikTokConfig *)tiktokConfig;

/**
 * @brief This method should be called in the didFinishLaunching method of your AppDelegate
 *        This is required to initialize the TikTokBusinessSDK
 *
 * @note See TikTokConfig.h for more configuration options
 *
 * @param tiktokConfig The configuration object must be initialized before this function is called.
 *                     This object contains the accessToken, appId and tiktokAppId which can be acquired from
 *                     TikTok's Marketing API dashboard.
 *
 * @param completionHandler Callback for starting the SDK.
*/
+ (void)initializeSdk: (nullable TikTokConfig *)tiktokConfig completionHandler:(void (^)(BOOL success, NSError * _Nullable error))completionHandler;

/**
 * @brief This method should be called whenever an event needs to be tracked
 *
 * @note See TikTokBaseEvent.h for more event options.
 *
 * @param eventName This parameter should be a string object. You can find the list of
 *                  supported events in the documentation.
 *                  You can either track a standardized event by passing a TTEventName or
 *                  trac a custom event by simply passing a custom name.
*/
+ (void)trackEvent: (NSString *)eventName;

/**
 * @brief This method should be called whenever an event needs to be tracked
 *
 * @note See TikTokBaseEvent.h for more event options.
 *
 * @param eventName This parameter should be a string object. You can find the list of
 *                  supported events in the documentation.
 *                  You can either track a standardized event by passing a TTEventName or
 *                  trac a custom event by simply passing a custom name.
 * @param properties This parameter should be a dictionary. For supported events,
 *                       the parameters passed should be formatted according to the
 *                       structure provided in the documentation. For custom events,
 *                       you can pass in custom properties
*/
+ (void)trackEvent: (NSString *)eventName withProperties: (NSDictionary *)properties;

/**
 * @brief This method should be called whenever an event needs to be tracked
 *
 * @note See TikTokBaseEvent.h for more event options.
 *
 * @param eventName This parameter should be a string object. You can find the list of
 *                  supported events in the documentation.
 *                  You can either track a standardized event by passing a TTEventName or
 *                  trac a custom event by simply passing a custom name.
 * @param type This parameter should be a string object ('track' or 'identify').
*/
+ (void)trackEvent: (NSString *)eventName withType: (NSString *)type;

/**
 * @brief This method should be called whenever an event needs to be tracked
 *
 * @note See TikTokBaseEvent.h for more event options.
 *
 * @param eventName This parameter should be a string object. You can find the list of
 *                  supported events in the documentation.
 *                  You can either track a standardized event by passing a TTEventName or
 *                  trac a custom event by simply passing a custom name.
 * @param eventId This parameter should be a string object. You can define a custom event identifier.
*/
+ (void)trackEvent: (NSString *)eventName withId: (NSString *)eventId;

/**
 * @brief This method should be called whenever an event needs to be tracked
 *
 * @note See TikTokBaseEvent.h for more event options.
 *
 * @param event This parameter should be a TikTokBaseEvent object. You can use TikTokContentsEvent
 *              or build a custom TikTokBaseEvent.
*/
+ (void)trackTTEvent: (TikTokBaseEvent *)event;

/**
 * @brief Use this method to enable or disable event tracking. Tracked events will still be cached locally until tracking is enabled again
*/
+ (void)setTrackingEnabled: (BOOL)enabled;

/**
 * @brief Use this method to disable collection of User Agent automatically and set a custom User Agent
*/
+ (void)setCustomUserAgent: (NSString *)customUserAgent;

/**
 * @brief Use this method once user has logged in or registered
*/
+ (void)identifyWithExternalID:(nullable NSString *)externalID
              externalUserName:(nullable NSString *)externalUserName
                   phoneNumber:(nullable NSString *)phoneNumber
                         email:(nullable NSString *)email;

/**
 * @brief Call this method when user has logged out
*/
+ (void)logout;

/**
 * @brief Call this method to explicitly flush
*/
+ (void)explicitlyFlush;

/**
 * @brief Use this method to update accessToken
*/
+ (void)updateAccessToken: (nonnull NSString *)accessToken;

/**
 * @brief Use this method to check if tracking has been enabled internally
 *        This method will return false **ONLY IF** tiktokConfig.disableTracking() is called
 *        before TikTokBusiness.initializeSdk() is called
*/
+ (BOOL)isTrackingEnabled;

/**
 * @brief Use this method to check if user has given permission to collect IDFA
 *        This method will return true if user chooses to let app track them after
 *        AppTrackingTransparency dialog is displayed in iOS 14.0 and onwards
*/
+ (BOOL)isUserTrackingEnabled;

/**
 * @brief Use this method to get the count of events that are currently in
 *        the event queue
*/
+ (long)getInMemoryEventCount;

/**
 * @brief Use this method to get the count of events that are currently in
 *        the disk and have to be flushed to the Marketing API endpoint
*/
+ (long)getInDiskEventCount;

/**
 * @brief Use this method to find the number of seconds before next flush
 *        to the Marketing API endpoint
*/
+ (long)getTimeInSecondsUntilFlush;

/**
 * @brief Use this method to find the threshold of the number of events that
 *        are flushed to the Marketing API
*/
+ (long)getRemainingEventsUntilFlushThreshold;

/**
 * @brief Retrieve iOS device IDFA value.
 *
 * @return Device IDFA value.
 */
+ (nullable NSString *)idfa;

/**
* @brief This method returns true if app is active and in the foreground
*/
+ (BOOL)appInForeground;

/**
 * @brief This method returns true if app is inactive and in the background
*/
+ (BOOL)appInBackground;

/**
 * @brief This method returns true if app is inactive or in the background
*/
+ (BOOL)appIsInactive;

/**
 * @brief Use this callback to display AppTrackingTransparency dialog to ask
 *        user for tracking permissions. This is a required method for any app
 *        that works on iOS 14.0 and above and that wants to track users through IDFA
*/
+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^_Nullable)(NSUInteger status))completion;

/*
 * @brief This method retruns true if SDK is in debug mode
*/
+ (BOOL)isDebugMode;

/**
 * @brief This method returns true if SDK is in LDU mode
 */
+ (BOOL)isLDUMode;

/**
 * @brief Use this method to check if the SDK is initialized.
*/
+ (BOOL)isInitialized;

/**
 *  @brief Obtain singleton TikTokBusiness class
 *  @return id referencing the singleton TikTokBusiness class
*/
+ (nullable id)getInstance;

/**
 *  @brief Reset TikTokBusiness class singleton
*/
+ (void)resetInstance;

/*
 * @brief This method returns the test event code
 *
 * @return Test event code
 *
 * @note only works in debug mode
*/
+ (NSString *)getTestEventCode;

/**
 *  @brief Produce a test exception
*/
+(void)produceFatalError;

/**
 *  @brief Method to get TikTok iOS SDK Version
*/
+ (NSString *)getSDKVersion;

@end

NS_ASSUME_NONNULL_END
