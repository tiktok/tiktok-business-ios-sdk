//
//  TikTokEDPConfig.h
//  TikTokBusinessSDK
//
//  Created by TikTok on 10/21/24.
//  Copyright © 2024 TikTok. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TikTokEDPConfig : NSObject

@property (nonatomic, assign) BOOL enable_sdk;
@property (nonatomic, assign) BOOL enable_from_ttconfig;
@property (nonatomic, assign) BOOL enable_app_launch_track;
@property (nonatomic, assign) BOOL enable_page_show_track;
@property (nonatomic, assign) BOOL enable_click_track;
@property (nonatomic, assign) BOOL enable_pay_show_track;
@property (nonatomic, assign) NSInteger page_detail_upload_deep_count;
@property (nonatomic, assign) double time_diff_frequency_control;
@property (nonatomic, assign) double report_frequency_control;
@property (nonatomic, strong) NSArray<NSString *> *button_black_list;
@property (nonatomic, strong) NSArray<NSString *> *sensig_filtering_regex_list;
@property (nonatomic, strong) NSNumber *sensig_filtering_regex_version;

+ (instancetype)sharedConfig;
- (void)configWithDict:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
