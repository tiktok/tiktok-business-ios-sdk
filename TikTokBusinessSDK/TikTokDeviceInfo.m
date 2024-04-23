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

@interface TikTokDeviceInfo()

@property (nonatomic, strong, readwrite) WKWebView *webView;

@end

@implementation TikTokDeviceInfo

+ (TikTokDeviceInfo *)deviceInfoWithSdkPrefix:(NSString *)sdkPrefix
{
    return [[TikTokDeviceInfo alloc] initWithSdkPrefix:sdkPrefix];
}

- (id)initWithSdkPrefix:(NSString *)sdkPrefix
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
    self.localeInfo = [NSString stringWithFormat:@"%@-%@", [locale objectForKey:NSLocaleLanguageCode], [locale objectForKey:NSLocaleCountryCode]];
    self.ipInfo = device.tiktokDeviceIp;
    self.trackingEnabled = device.tiktokUserTrackingEnabled;
    self.deviceType = device.tiktokDeviceType;
    self.deviceName = device.tiktokDeviceName;
    self.systemVersion = device.systemVersion;
    
    return self;
    
}

- (NSString *)getUserAgent
{
    return [TikTokUserAgentCollector singleton].userAgent;
}

- (void)collectUserAgentWithCompletion:(void (^)(NSString *userAgent))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.webView) {
            self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
        }
        
        [self.webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id _Nullable response, NSError * _Nullable error) {
            if(completion){
                if(response) {
                    self.webView = nil;
                    completion(response);
                } else {
                    [self collectUserAgentWithCompletion:completion];
                }
            }
        }];
    });
}


static NSString * getIDFA(void) {
    ASIdentifierManager *sharedASIdentifierManager = [ASIdentifierManager sharedManager];
    NSUUID *adID = [sharedASIdentifierManager advertisingIdentifier];
    NSString *IDFA = [adID UUIDString];
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
static NSString* deviceVersion()
{
    NSString *systemName = [UIDevice currentDevice].systemName;
    NSString *systemVersion = [UIDevice currentDevice].systemVersion;
    
    return [NSString stringWithFormat:@"%@/%@", systemName, systemVersion];
}

//eg. iPhone5,2
static NSString* deviceName()
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithUTF8String:systemInfo.machine];
}

//eg. MyApp/1
static NSString* appNameAndVersion()
{
    NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString* appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return [NSString stringWithFormat:@"%@/%@", appName, appVersion];
}

static NSString* phoneResolution()
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

@end
