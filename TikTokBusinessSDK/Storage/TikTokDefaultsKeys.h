//
//  TikTokDefaultsKeys.h
//  TikTokBusinessSDK
//
//  Copyright © 2025 TikTok. All rights reserved.
//
//  Centralized UserDefaults keys for [TikTokDefaults storage].
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Source / Referrer

#define TikTokDefaultsKeySourceURL @"source_url"
#define TikTokDefaultsKeyRefer @"refer"

#pragma mark - Timer & flush

#define TikTokDefaultsKeyAreTimersOn @"AreTimersOn"
#define TikTokDefaultsKeyHasFirstFlushOccurred @"HasFirstFlushOccurred"

#pragma mark - Monitor

#define TikTokDefaultsKeyMonitorInitStartTime @"monitorInitStartTime"
#define TikTokDefaultsKeyBackgroundMonitorTime @"backgroundMonitorTime"
#define TikTokDefaultsKeyForegroundMonitorTime @"foregroundMonitorTime"

#pragma mark - Initialization & install

#define TikTokDefaultsKeyHasBeenInitialized @"HasBeenInitialized"
#define TikTokDefaultsKeyTikTokInstallDate @"tiktokInstallDate"
#define TikTokDefaultsKeyTikTokLaunchedBefore @"tiktokLaunchedBefore"
#define TikTokDefaultsKeyTikTokMatchedInstall @"tiktokMatchedInstall"
#define TikTokDefaultsKeyTikTokLogged2DRetention @"tiktokLogged2DRetention"
#define TikTokDefaultsKeyTikTokPast2DLimit @"tiktokPast2DLimit"

#pragma mark - Identify

#define TikTokDefaultsKeyAnonymousID @"AnonymousID"

#pragma mark - User agent

#define TikTokDefaultsKeyUserAgent @"TT_UserAgent"

#pragma mark - Payment

#define TikTokDefaultsKeyPaymentObserverOriginalTransaction @"com.tiktok.appevents.PaymentObserver.originalTransaction"

#pragma mark - View / sensitivity

#define TikTokDefaultsKeySensigFilteringRegexPattern @"sensig_filtering_regex_pattern"
#define TikTokDefaultsKeySensigFilteringRegexVersion @"sensig_filtering_regex_version"

#pragma mark - Debug / boot time

#define TTBTSDictKey (@"bootTimeSDict")
#define TTBTMsDictKey (@"bootTimeMsDict")

#pragma mark - SKAdNetwork

#define TTUserDefaultsKey_firstLaunchTime @"firstLaunchTime"
#define TTAccumulatedSKANValuesKey @"accumulatedSKANValues"
#define TTLatestFineValueKey @"latestFineValue"
#define TTLatestCoarseValueKey @"latestCoarseValue"
#define TTSKANTimeWindowKey @"SKANTimeWindow"

NS_ASSUME_NONNULL_END
