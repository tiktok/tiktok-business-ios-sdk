//
//  TikTokDebugInfo.m
//  TikTokBusinessSDK
//
//  Created by Chuanqi on 7/11/25.
//  Copyright © 2025 TikTok. All rights reserved.
//

#import "TikTokDebugInfo.h"
#import "TikTokTypeUtility.h"
#import <sys/sysctl.h>
#import "TikTokAppEventUtility.h"
#import <UIKit/UIKit.h>
#import "TikTokBusinessSDKMacros.h"
#import "TikTokDefaults.h"
#import "TikTokDefaultsKeys.h"

#define MAX_BT_ARRAY_SIZE 3

@implementation TikTokDebugInfo

+ (NSDictionary *)debugInfo {
    NSMutableDictionary *debugInfo = [NSMutableDictionary dictionary];
    NSString *bootTime = [self tt_bootTime];
    NSUserDefaults *userDefaults = [TikTokDefaults storage];
    NSDictionary *btSDict = [userDefaults objectForKey:TTBTSDictKey];
    NSArray *bootTimeSArray = TTCheckValidDictionary(btSDict) ? btSDict.allKeys : @[];
    NSDictionary *btMsDict = [userDefaults objectForKey:TTBTMsDictKey];
    NSArray *bootTimeMsArray = TTCheckValidDictionary(btMsDict) ? btMsDict.allKeys : @[];
    
    [debugInfo setValue:TTSafeString(bootTime) forKey:@"bt"];
    [debugInfo setValue:bootTimeSArray forKey:@"bt_s"];
    [debugInfo setValue:bootTimeMsArray forKey:@"bt_ms"];
    [debugInfo setValue:[self tt_machine_model] forKey:@"machine_model"];
    [debugInfo setValue:@([self tt_totalDeviceMemory]) forKey:@"memory"];
    [debugInfo setValue:TTSafeString([self tt_screenResolutionString]) forKey:@"resolution"];
    [debugInfo setValue:@([self tt_cpuNumber]) forKey:@"cpu_num"];
    
    
    //region info
    [debugInfo setValue:[self tt_timezoneName] forKey:@"timezone_name"];
    [debugInfo setValue:[self tt_deviceCity] forKey:@"country_city"];
    
    
    return debugInfo.copy;
}

+ (NSString *)tt_bootTime {
    static long long bt = -1;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct timeval value = {0};
        size_t size = sizeof(value);
        sysctlbyname("kern.boottime", &value, &size, NULL, 0);
        bt = value.tv_sec * 1000 + value.tv_usec / 1000;
        [self updateBootTimeIfNeeded:bt];
    });
    return [NSString stringWithFormat:@"%lld", bt];
}

+ (void)updateBootTimeIfNeeded:(long long)bootTime {
    [self updateBootTimeWithValue:bootTime
                           forKey:TTBTMsDictKey
                     maxArraySize:MAX_BT_ARRAY_SIZE];
    
    [self updateBootTimeWithValue:bootTime / 1000
                           forKey:TTBTSDictKey
                     maxArraySize:MAX_BT_ARRAY_SIZE];
}

+ (void)updateBootTimeWithValue:(long long)bootTime
                         forKey:(NSString *)key
                   maxArraySize:(NSInteger)maxArraySize {
    NSUserDefaults *userDefaults = [TikTokDefaults storage];
    NSMutableDictionary *dict = [userDefaults objectForKey:key];
    long long currentTimestamp = [TikTokAppEventUtility getCurrentTimestamp];
    if (TTCheckValidDictionary([userDefaults objectForKey:key])) {
        dict = ((NSDictionary *)[userDefaults objectForKey:key]).mutableCopy;
    } else {
        dict = [NSMutableDictionary dictionary];
    }
    NSString *updateValue = [NSString stringWithFormat:@"%lld", bootTime];
    // remove expired boottime
    NSMutableArray *expiredKeys = [NSMutableArray array];
    for (NSString *existingKey in dict.allKeys) {
        long long time = [[dict objectForKey:existingKey] longLongValue];
        if ((currentTimestamp - time) > 30LL * 86400000) {
            [expiredKeys addObject:existingKey];
        }
    }
    [dict removeObjectsForKeys:expiredKeys.copy];
    // update or insert new boottime
    if ([dict objectForKey:updateValue]) {
        [dict setObject:@(currentTimestamp) forKey:updateValue];
    } else {
        if (dict.count >= maxArraySize) {
            NSString *oldestKey = nil;
            long long minTime = currentTimestamp;
            for (NSString *existingKey in dict.allKeys) {
                long long time = [[dict objectForKey:existingKey] longLongValue];
                if (time < minTime) {
                    minTime = time;
                    oldestKey = existingKey;
                }
            }
            if (TTCheckValidString(oldestKey)) {
                [dict removeObjectForKey:oldestKey];
            }
        }
        [dict setObject:@(currentTimestamp) forKey:updateValue];
    }
    [userDefaults setObject:dict.copy forKey:key];
    [userDefaults synchronize];
}

+ (NSString *)tt_screenResolutionString {
    static NSString *resolutionStr = @"";
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        CGFloat scale = [[UIScreen mainScreen] scale];
        CGSize resolution = CGSizeMake(screenBounds.size.width * scale, screenBounds.size.height * scale);
        resolutionStr = [NSString stringWithFormat:@"%d*%d", (int)resolution.width, (int)resolution.height];
    });
    return resolutionStr;
}

+ (NSInteger)tt_cpuNumber {
    static unsigned int ncpu;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size_t len = sizeof(ncpu);
        sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
    });
    return (NSInteger)ncpu;
}

+ (NSInteger)tt_totalDeviceMemory {
    static NSInteger totalMemory = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        totalMemory = (NSUInteger)[[NSProcessInfo processInfo] physicalMemory] / 1024 / 1024;
    });
    return totalMemory;
}

+ (NSString *)tt_model {
    static NSString *model = @"";
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        model = [self getDevInfoByName:"hw.model"];
    });
    return model;
}

+ (NSString *)tt_machine_model {
    static NSString *machine_model = @"";
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *machine = [self getDevInfoByName:"hw.machine"];
        NSString *model = [self getDevInfoByName:"hw.model"];
        machine_model = [NSString stringWithFormat:@"%@/%@",machine,model];
    });
    return machine_model;
}

+ (NSString *)getDevInfoByName:(char *)typeSpecifier {
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

+ (NSString *)tt_deviceCity {
    static NSString *city = @"";
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        city = [[NSTimeZone systemTimeZone] name];
    });
    return city;
}

+ (NSString *)tt_timezoneName {
    static NSString *timeZone = @"";
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timeZone = [[NSTimeZone systemTimeZone] abbreviation];
        //Japan time zone issue http://www.timeofdate.com/timezone/abbr/JST/Japan%20Standard%20Time
        if ([timeZone isEqualToString:@"JST"]) {
            timeZone = @"GMT+9";
        }
        if ([timeZone containsString:@"+"]) {
            timeZone = [timeZone stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
        } else if ([timeZone containsString:@"-"]) {
            timeZone = [timeZone stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
        } else {
        }
        timeZone = [NSString stringWithFormat:@"Etc/%@", timeZone];
    });
    return timeZone;
}


@end
