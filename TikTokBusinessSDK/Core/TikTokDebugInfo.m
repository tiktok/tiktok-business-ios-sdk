//
//  TikTokDebugInfo.m
//  TikTokBusinessSDK
//
//  Created by Chuanqi on 7/11/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokDebugInfo.h"

@implementation TikTokDebugInfo

// Retired in this fork: detailed hardware/timezone and boot-history telemetry is
// unnecessary for attribution. Keep the selector compatible without collecting it.
+ (NSDictionary *)debugInfo {
    [self clearLegacyTelemetry];
    return @{};
}

+ (BOOL)clearLegacyTelemetry {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObjectForKey:TTBTMsDictKey];
    [defaults removeObjectForKey:TTBTSDictKey];
    return [defaults objectForKey:TTBTMsDictKey] == nil &&
        [defaults objectForKey:TTBTSDictKey] == nil;
}

+ (BOOL)isRetiredMonitor:(NSDictionary *)properties {
    return [properties[@"monitor_name"] isEqual:@"debug_info"];
}

@end
