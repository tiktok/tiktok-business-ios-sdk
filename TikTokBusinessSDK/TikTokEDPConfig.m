//
//  TikTokEDPConfig.m
//  TikTokBusinessSDK
//
//  Created by TikTok on 10/21/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import "TikTokEDPConfig.h"
#import "TikTokTypeUtility.h"
#import "TikTokBusinessSDKMacros.h"

#define DEFAULT_DEEP_COUNT 12

@implementation TikTokEDPConfig

+ (TikTokEDPConfig *)sharedConfig {
    static TikTokEDPConfig *singleton;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[TikTokEDPConfig alloc] init];
    });
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.enable_sdk = NO;
        self.enable_app_launch_track = NO;
        self.enable_page_show_track = NO;
        self.enable_click_track = NO;
        self.enable_pay_show_track = NO;
        self.page_detail_upload_deep_count = DEFAULT_DEEP_COUNT;
        self.time_diff_frequency_control = 0;
        self.report_frequency_control = 1;
        self.button_black_list = @[];
        self.sensig_filtering_regex_list = @[];
        self.enable_from_ttconfig = NO;
    }
    return self;
}

- (void)configWithDict:(NSDictionary *)dict {
    self.enable_sdk = [[dict objectForKey:@"enable_sdk"] boolValue];
    self.enable_app_launch_track = [[dict objectForKey:@"enable_app_launch_track"] boolValue];
    self.enable_page_show_track = [[dict objectForKey:@"enable_page_show_track"] boolValue];
    self.enable_click_track = [[dict objectForKey:@"enable_click_track"] boolValue];
    self.enable_pay_show_track = [[dict objectForKey:@"enable_pay_show_track"] boolValue];
    
    NSNumber *deepCount = [dict objectForKey:@"page_detail_upload_deep_count"];
    if (TTCheckValidNumber(deepCount)) {
        self.page_detail_upload_deep_count = [deepCount intValue];
    }
    NSNumber *timeFrequency = [dict objectForKey:@"time_diff_frequency_control"];
    if (TTCheckValidNumber(timeFrequency)) {
        self.time_diff_frequency_control = [timeFrequency doubleValue];
    }
    NSNumber *reportFrequency = [dict objectForKey:@"report_frequency_control"];
    if (TTCheckValidNumber(reportFrequency)) {
        self.report_frequency_control = [reportFrequency doubleValue];
    }
    NSArray *buttonBlackList = [dict objectForKey:@"button_black_list"];
    if (TTCheckValidArray(buttonBlackList)) {
        self.button_black_list = buttonBlackList;
    }
    NSArray *sensigRegexList = [dict objectForKey:@"sensig_filtering_regex_list"];
    if (TTCheckValidArray(sensigRegexList)) {
        self.sensig_filtering_regex_list = sensigRegexList;
    }
    NSNumber *regexVersion = [dict objectForKey:@"sensig_filtering_regex_version"];
    if (TTCheckValidNumber(regexVersion)) {
        self.sensig_filtering_regex_version = regexVersion;
    }
}

@end
