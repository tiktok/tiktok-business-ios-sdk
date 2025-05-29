//
// Copyright (c) 2020. TikTok Inc.
//
// This source code is licensed under the MIT license found in
// the LICENSE file in the root directory of this source tree.
//

#import "TikTokDeviceInfo.h"
#import <sys/utsname.h>
#import <AdSupport/ASIdentifierManager.h>
#import "UIDevice+TikTokAdditions.h"
#import "TikTokUserAgentCollector.h"
#import "TikTokAppEventUtility.h"
#import "TikTokBusiness.h"
#import "TikTokAppEvent.h"
#import "TikTokBusiness+private.h"
#import <AVFoundation/AVFoundation.h>
#import "TikTokBusinessSDKMacros.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <SystemConfiguration/SCNetworkReachability.h>

static NSInteger const TTSystemVolumeValueDefault = -1;


@interface TikTokDeviceInfo()

@property (nonatomic, strong) dispatch_queue_t deviceQueue;

@end

@implementation TikTokDeviceInfo

+ (TikTokDeviceInfo *)deviceInfo
{
    static id deviceInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        deviceInfo = [[self alloc] init];
    });
    return deviceInfo;
}

- (instancetype)init
{
    self = [super init];
    if (self == nil) return nil;
    
    UIDevice *device = UIDevice.currentDevice;
    NSLocale *locale = NSLocale.currentLocale;
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *infoDictionary = bundle.infoDictionary;

    self.appId = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    self.appName = [infoDictionary objectForKey:@"CFBundleName"];
    self.appNamespace = [infoDictionary objectForKey: (NSString *)kCFBundleIdentifierKey];
    self.appVersion = [infoDictionary objectForKey: @"CFBundleShortVersionString"];
    self.appBuild = [infoDictionary objectForKey: (NSString *)kCFBundleVersionKey];
    self.devicePlatform = @"ios";
    self.deviceIdForAdvertisers = getIDFA();
    self.deviceVendorId = device.tiktokVendorId;
    self.localeInfo = [NSString stringWithFormat:@"%@/%@", [self language], [locale objectForKey:NSLocaleCountryCode]];
    self.ipInfo = device.tiktokDeviceIp;
    self.trackingEnabled = device.tiktokUserTrackingEnabled;
    self.deviceName = device.tiktokDeviceName;
    self.systemVersion = device.systemVersion;
    self.deviceQueue = dispatch_queue_create([@"com.TikTokBusinessSDK.device" UTF8String], DISPATCH_QUEUE_CONCURRENT);
    self.systemVolume = TTSystemVolumeValueDefault;
    self.headset = TTDeviceHeadsetUnspecified;
    
    [self updateIdentifier];
    
    
    return self;
    
}

- (void)updateIdentifier {
    [self _setSystemVolume];
    [self _setHeadset];
    [self _checkUserInterfaceStyle];
    if (self.deviceIdForAdvertisers.length && ![self.deviceIdForAdvertisers isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        return;
    }
    self.deviceIdForAdvertisers = getIDFA();
}

- (NSString *)getUserAgent
{
    return [TikTokUserAgentCollector singleton].userAgent;
}


static NSString * getIDFA(void) {
    NSNumber *idfaStartTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
    ASIdentifierManager *sharedASIdentifierManager = [ASIdentifierManager sharedManager];
    NSUUID *adID = [sharedASIdentifierManager advertisingIdentifier];
    NSString *IDFA = [adID UUIDString];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL success = IDFA.length && ![IDFA isEqualToString:@"00000000-0000-0000-0000-000000000000"];
        NSNumber *idfaEndTime = [TikTokAppEventUtility getCurrentTimestampAsNumber];
        NSDictionary *idfaStartMeta = @{
            @"ts": idfaStartTime,
        };
        NSDictionary *idfaStartProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"did_start",
            @"meta": idfaStartMeta
        };
        NSDictionary *idfaEndMeta = @{
            @"ts": idfaEndTime,
            @"latency": [NSNumber numberWithLongLong:[idfaEndTime longLongValue] - [idfaStartTime longLongValue]],
            @"success": @(success),
        };
        NSDictionary *idfaEndProperties = @{
            @"monitor_type": @"metric",
            @"monitor_name": @"did_end",
            @"meta": idfaEndMeta
        };
        TikTokAppEvent *idfaStartEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:idfaStartProperties withType:@"monitor"];
        TikTokAppEvent *idfaEndEvent = [[TikTokAppEvent alloc] initWithEventName:@"MonitorEvent" withProperties:idfaEndProperties withType:@"monitor"];
        [[TikTokBusiness getEventLogger] addEvent:idfaStartEvent];
        [[TikTokBusiness getEventLogger] addEvent:idfaEndEvent];
    });
    return IDFA;
}

//eg. Darwin/16.3.0
static NSString * DarwinVersion(void) {
    struct utsname u;
    (void) uname(&u);
    return [NSString stringWithFormat:@"Darwin/%@", [NSString stringWithUTF8String:u.release]];
}

//eg. CFNetwork/808.3
static NSString * CFNetworkVersion(void) {
    return [NSString stringWithFormat:@"CFNetwork/%@", [NSBundle bundleWithIdentifier:@"com.apple.CFNetwork"].infoDictionary[@"CFBundleShortVersionString"]];
}

//eg. iOS/10_1
static NSString* deviceVersion(void)
{
    NSString *systemName = [UIDevice currentDevice].systemName;
    NSString *systemVersion = [UIDevice currentDevice].systemVersion;
    
    return [NSString stringWithFormat:@"%@/%@", systemName, systemVersion];
}

//eg. iPhone5,2
static NSString* deviceName(void)
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithUTF8String:systemInfo.machine];
}

//eg. MyApp/1
static NSString* appNameAndVersion(void)
{
    NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString* appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return [NSString stringWithFormat:@"%@/%@", appName, appVersion];
}

static NSString* phoneResolution(void)
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;
    NSString *resolution = [NSString stringWithFormat:@"Resolution/%d*%d", (int)screenWidth, (int)screenHeight];
    return resolution;
}

- (NSString*)fallbackUserAgent
{
    return [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@", appNameAndVersion(), deviceName(), deviceVersion(), CFNetworkVersion(), DarwinVersion(), phoneResolution()];
}

- (NSString *)language {
    NSString *language;
    NSLocale *locale = [NSLocale currentLocale];
    if ([[NSLocale preferredLanguages] count] > 0) {
        language = [[NSLocale preferredLanguages]objectAtIndex:0];
    } else {
        language = [locale objectForKey:NSLocaleLanguageCode];
    }
    return language;
}

- (void)_setSystemVolume {
    dispatch_async(self.deviceQueue, ^{
        self.systemVolume = [AVAudioSession sharedInstance].outputVolume * 100;
    });
}

- (NSInteger)volume { //not strong requirement for real-time value, report the value of last time
    dispatch_async(self.deviceQueue, ^{
        self.systemVolume = [AVAudioSession sharedInstance].outputVolume * 100;
    });
    return self.systemVolume;
}

- (void)_setHeadset {
    dispatch_async(self.deviceQueue, ^{
        BOOL hasHeadset = NO;
        AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
        for (AVAudioSessionPortDescription *des in route.outputs) {
            if ([des.portType isEqualToString:AVAudioSessionPortHeadphones]) {
                hasHeadset = YES;
                break;
            }
        }
        self.headset = hasHeadset;
    });
}

- (void)_checkUserInterfaceStyle {
    tt_weakify(self)
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
        tt_strongify(self)
        UIUserInterfaceStyle userInterfaceStyle = [[UIApplication sharedApplication]keyWindow].rootViewController.traitCollection.userInterfaceStyle;
        TTDeviceDarkMode mode = TTDeviceDarkModeUnspecified;
        switch (userInterfaceStyle) {
            case UIUserInterfaceStyleLight:
                mode = TTDeviceDarkModeLight;
                break;
            case UIUserInterfaceStyleDark:
                mode = TTDeviceDarkModeDark;
                break;
            default:
                mode = TTDeviceDarkModeUnspecified;
                break;
        }
        self.darkmode = mode;
    }];
}

@end
